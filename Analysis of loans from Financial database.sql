USE financial8_52;

-- Struktura bazy | PK - żółty kluczyk, FK - niebieski kluczyk
-- Sprawdzenie relacji między tabelami

# account - account_id (PK), district_id (FK) w relacji n-1 z uwagi na account
SELECT
    district_id, # FK
    count(account_id) # PK
FROM account
GROUP BY district_id # FK
ORDER BY 2 DESC; # PK

# card - card_id (PK), disp_id (FK) w relacji 1-1 z uwagi na card
SELECT
    disp_id, # FK
    count(card_id) # PK
FROM card
GROUP BY disp_id # FK
ORDER BY 2 DESC; # PK

# client - client_id (PK), district_id (FK) w relacji n-1 z uwagi na client
SELECT
    district_id, # FK
    count(client_id) # PK
FROM client
GROUP BY district_id # FK
ORDER BY 2 DESC; # PK

# disp - disp_id (PK), client_id (FK) w relacji 1-1 z uwagi na disp, account_id (FK) n-1 z uwagi na disp
SELECT
    client_id, # FK
    count(disp_id) # PK
FROM disp
GROUP BY client_id # FK
ORDER BY 2 DESC; # PK

SELECT
    account_id, # FK
    count(disp_id) # PK
FROM disp
GROUP BY account_id # FK
ORDER BY 2 DESC; # PK

# district - district (PK), no FK

# loan- loan_id (PK), account_id (FK) w relacji 1-1 z uwagi na loan
SELECT
    account_id, # FK
    count(loan_id) # PK
FROM loan
GROUP BY account_id # FK
ORDER BY 2 DESC; # PK

# `order`- order_id (PK), account_id (FK) w relacji n-1 z uwagi na `order`
SELECT
    account_id, # FK
    count(order_id) # PK
FROM `order`
GROUP BY account_id # FK
ORDER BY 2 DESC; # PK

# trans - trans_id (PK), account_id (FK) w relacji n-1 z uwagi na trans (1 unikalna transakcja ma 1 konto, 1 unikalne konto ma wiele transakcji)
SELECT
    account_id, # FK
    count(trans_id) # PK
FROM trans
GROUP BY account_id # FK
ORDER BY 2 DESC; # PK

-- Historia udzielanych kredytów
/* Podsumowuję udzielane kredyty w następujących wymiarach:

- rok, kwartał, miesiąc,
- rok, kwartał,
- rok,
- sumarycznie.

Jako wynik podsumowania wyświetlam następujące informacje:
- sumaryczna kwota pożyczek,
- średnia kwota pożyczki,
- całkowita liczba udzielonych pożyczek.*/

SELECT
          YEAR(date)
        , QUARTER(date)
        , MONTH(date)
        , SUM(payments)
        , AVG(payments)
        , COUNT(payments)
FROM loan
GROUP BY 1, 2, 3
WITH ROLLUP;

-- Status pożyczki
/* Wiedząc że w bazie znajdują się w sumie 682 udzielone kredyty, z czego 606 zostało spłaconych, a 76 nie,
   sprawdzam które statusy oznaczają pożyczki spłacone, a które oznaczają pożyczki niespłacone.*/

SELECT status
     , count(status)
     , IF(status = 'A' OR status = 'C', 'PAID', 'NOT PAID') as status_name
FROM loan
GROUP BY `status`;


WITH cte AS (
    SELECT
        status,
        COUNT(status) AS liczba,
        IF(status = 'A' OR status = 'C', 'PAID', 'NOT PAID') as status_name
    FROM loan
    GROUP BY status
)
SELECT
    status_name,
    SUM(liczba) AS suma_pozyczek
FROM cte
GROUP BY status_name;


-- Analiza kont
/*Analizuję spłacone pożyczki według następujących kryteriów:

- średnia kwota pożyczki,
- kwota udzielonych pożyczek (malejąco)
- liczba udzielonych pożyczek (malejąco).
*/

SELECT account_id
    , count(loan_id)
    , sum(amount)
    , avg(amount)
    , ROW_NUMBER() over (ORDER BY sum(amount) DESC) AS rank_loans_amount
    , ROW_NUMBER() over (ORDER BY count(loan_id) DESC) AS rank_loans_count
FROM loan
WHERE status IN ('A', 'C')
GROUP BY account_id
;

-- Spłacone pożyczki
/* Sprawdzam, ile pożyczek zostało spłaconych w podziale na płeć klienta.*/

SELECT gender
    , sum(amount) AS amount
FROM loan
JOIN disp as d USING(account_id)
JOIN client as c USING(client_id)
WHERE status IN ('A', 'C') AND type = 'OWNER'
GROUP BY gender;

# 43256388 (M)
# 44425200 (K)

#  + sprawdzenie - czy zgrupowane zapytanie z JOINami jest rownowazne z sumą w tabeli loan

WITH cte AS (SELECT gender
                    , sum(amount) AS amount
                FROM loan
                JOIN disp as d USING(account_id)
                JOIN client as c USING(client_id)
                WHERE status IN ('A', 'C') AND type = 'OWNER'
                GROUP BY gender)
SELECT (SELECT sum(amount)
        FROM loan
        WHERE status IN ('A', 'C')) - (SELECT sum(amount) FROM cte)
; # spr = 0

-- Analiza klienta cz. 1
/* Chcę odpowiedzieć na pytania:

1) kto posiada więcej spłaconych pożyczek – kobiety czy mężczyźni? # F
2) jaki jest średni wiek kredytobiorcy w zależności od płci? # F 64.5 / M 66.5
*/

CREATE TEMPORARY TABLE IF NOT EXISTS temp_analiza AS
SELECT gender
    , count(loan_id) AS loan_count
    , sum(amount) AS amount
    , YEAR(NOW()) - YEAR(birth_date) AS age
FROM loan
JOIN disp as d USING(account_id)
JOIN client as c USING(client_id)
WHERE status IN ('A', 'C') AND type = 'OWNER'
GROUP BY gender, age
ORDER BY amount DESC;

-- odpowiedzi
SELECT
    gender
    , sum(amount) AS amount
    , SUM(loan_count) as loans_count
    , avg(age) as avg_age
FROM temp_analiza
GROUP BY gender
WITH ROLLUP
;


-- Analiza klienta cz. 2
/* Biorąc pod uwagę tylko właścicieli kont hcę odpowiedzieć na pytania:

1) w którym rejonie jest najwięcej klientów,
2) w którym rejonie zostało spłaconych najwięcej pożyczek ilościowo,
3) w którym rejonie zostało spłaconych najwięcej pożyczek kwotowo.
*/

CREATE TEMPORARY TABLE temp_region_analytics AS
SELECT A3 as region
     , count(distinct client_id) AS client_count
     , count(loan_id) AS loan_count
     , sum(amount) AS loan_amount
FROM loan
JOIN disp as d USING(account_id)
JOIN client as c USING(client_id)
JOIN district AS dc USING(district_id)
WHERE status IN ('A', 'C') AND type = 'OWNER'
GROUP BY region;

SELECT *
FROM temp_region_analytics
ORDER BY client_count DESC
LIMIT 1;

SELECT *
FROM temp_region_analytics
ORDER BY loan_count DESC
LIMIT 1;

SELECT *
FROM temp_region_analytics
ORDER BY loan_amount DESC
LIMIT 1;


-- Analiza klienta cz. 3
/* Chcę wyznaczyć procentowy udział każdego regionu w całkowitej kwocie udzielonych pożyczek.*/

-- z podzialem na district_id
WITH cte AS (SELECT district_id               as district
                      , count(distinct client_id) AS client_count
                      , count(loan_id)            AS loan_count
                      , sum(amount)               AS amount
                 FROM loan
                          JOIN disp as d USING (account_id)
                          JOIN client as c USING (client_id)
                          JOIN district AS dc USING (district_id)
                 WHERE status IN ('A', 'C')
                   AND type = 'OWNER'
                 GROUP BY district_id
#                  ORDER BY client_count DESC, loan_count DESC, amount DESC
)
SELECT *
     , SUM(amount) OVER() AS total_loan
     , amount / SUM(amount) OVER() * 100 AS perc_share_per_region
FROM cte
ORDER BY perc_share_per_region DESC
;

-- Selekcja klientów
/*Sprawdzam, czy w bazie występują klienci spełniający poniższe warunki:

- saldo konta przekracza 1000,
- mają więcej niż pięć pożyczek,
- są urodzeni po 1980 r.
Przy czym zakładam, że saldo konta to kwota pożyczki - wpłaty.*/

-- check kto jest urodzony po 1980
SELECT client_id
FROM `client`
WHERE YEAR(birth_date) > 1980;

-- zapytanie które nie zwraca nic
SELECT c.client_id
    , sum(l.amount - l.payments) AS client_balance
    , count(l.loan_id) AS loan_count
FROM loan as l
JOIN disp as d USING(account_id)
JOIN `client` as c USING(client_id)
JOIN district AS dc USING(district_id)
WHERE l.status IN ('A', 'C') AND YEAR(c.birth_date) > 1980
GROUP BY c.client_id
HAVING loan_count > 5 AND client_balance > 1000
;
# brak wyników, każdy klient miał tylko 1 pożyczkę

SELECT c.client_id
    , sum(l.amount - l.payments) AS client_balance
    , count(l.loan_id) AS loan_count
FROM loan as l
JOIN disp as d USING(account_id)
JOIN `client` as c USING(client_id)
JOIN district AS dc USING(district_id)
WHERE l.status IN ('A', 'C') AND YEAR(c.birth_date) > 1980
GROUP BY c.client_id
HAVING client_balance > 1000;

-- Wygasające karty
/*Tworzę procedurę, która będzie odświeżać tabelę zawierającą następujące kolumny:

- id klienta,
- id_karty,
- data wygaśnięcia – zakładam, że karta może być aktywna przez 3 lata od wydania,
- adres klienta (wystarczy kolumna A3).
Uwaga: W tabeli card zawarte są karty, które zostały wydane do końca 1998.*/


-- zapytanie do tabeli
WITH cte AS (
    SELECT d.client_id
        , c.card_id
        , ADDDATE(issued, INTERVAL 3 YEAR) AS expiry_date
        , A3 AS client_address
    FROM card AS c
    JOIN disp AS d USING(disp_id)
    JOIN client AS cl USING(client_id)
    JOIN district AS di USING(district_id)
    ORDER BY expiry_date)
SELECT *
FROM cte
WHERE expiry_date BETWEEN '2001-01-05' AND ADDDATE('2001-01-05', INTERVAL 7 DAY)
;

-- tworzę tabele
CREATE TABLE cards_at_expiration
(
    client_id           int                      not null,
    card_id             int default 0            not null,
    expiration_date     date                     null,
    client_address      varchar(20) charset utf8 not null,
    generated_for_date  date                     null
);

-- procedura
DELIMITER $$
CREATE PROCEDURE cards_at_expiration_report(IN date_input DATE)
BEGIN
    TRUNCATE cards_at_expiration;
    INSERT INTO cards_at_expiration
    WITH cte AS (
        SELECT d.client_id
            , c.card_id
            , ADDDATE(issued, INTERVAL 3 YEAR) AS expiry_date
            , A3 AS client_address
        FROM card AS c
        JOIN disp AS d USING(disp_id)
        JOIN client AS cl USING(client_id)
        JOIN district AS di USING(district_id)
        ORDER BY expiry_date)
    SELECT *
        , date_input
    FROM cte
    WHERE expiry_date BETWEEN date_input AND ADDDATE(date_input, INTERVAL 7 DAY);
END $$
DELIMITER ;

CALL cards_at_expiration_report('2001-01-05');
SELECT * FROM cards_at_expiration;
