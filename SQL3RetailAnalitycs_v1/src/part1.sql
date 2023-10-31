-- CREATE DATABASE RetailAnalitycs_v1;
DROP TABLE IF EXISTS Personal_Information, Cards, Transactions, Checks, Product_Grid, Stores, SKU_Group, Date_of_Analysis CASCADE;
DROP PROCEDURE IF EXISTS csv_import(filepath text, delimiter char) CASCADE;
DROP PROCEDURE IF EXISTS csv_export(filepath text, delimiter char) CASCADE;

CREATE TABLE IF NOT EXISTS Personal_Information
(
    Customer_ID serial NOT NULL primary key,
    Customer_Name varchar NOT NULL,
    Customer_Surname varchar NOT NULL,
    Customer_Primary_Email text NOT NULL,
    Customer_Primary_Phone text NOT NULL,
    CHECK (
        Customer_Name ~ '^[A-ZА-Я][a-zа-я\s-]+$' AND
        Customer_Surname ~ '^[A-ZА-Я][a-zа-я\s-]+$' AND
        Customer_Primary_Email ~ '^[A-Za-z0-9._%-]+@[A-Za-z0-9.-]+[.][A-Za-z]+$'  AND
        Customer_Primary_Phone ~ '^[+]7\d{10}$'
    )
);

CREATE TABLE IF NOT EXISTS Cards
(
    Customer_Card_ID serial NOT NULL primary key,
    Customer_ID serial NOT NULL,
    constraint fk_Customer_ID foreign key (Customer_ID) references Personal_Information(Customer_ID)
);

CREATE TABLE IF NOT EXISTS SKU_Group
(
    Group_ID serial NOT NULL,
    Group_Name varchar NOT NULL,
    UNIQUE (Group_ID),
    CHECK (
        Group_Name ~ '^[A-Za-zА-Яа-я0-9\W]+$'
    )
);

CREATE TABLE IF NOT EXISTS Product_Grid
(
    SKU_ID serial NOT NULL primary key,
    SKU_Name varchar NOT NULL,
    Group_ID serial NOT NULL,
    constraint fk_Group_ID foreign key (Group_ID) references SKU_Group(Group_ID),
    CHECK (
        SKU_Name ~ '^[A-Za-zА-Яа-я0-9\W]+$'
    )
);

CREATE TABLE IF NOT EXISTS Stores
(
    Transaction_Store_ID serial NOT NULL,
    SKU_ID serial NOT NULL,
    SKU_Purchase_Price numeric NOT NULL,
    SKU_Retail_Price numeric NOT NULL,
    constraint fk_SKU_ID foreign key (SKU_ID) references Product_Grid(SKU_ID)
);

SET datestyle = DMY;
SET lc_monetary = 'ru_RU.utf8';
CREATE TABLE IF NOT EXISTS Transactions
(
    Transaction_ID serial NOT NULL primary key,
    Customer_Card_ID serial NOT NULL,
    Transaction_Summ numeric NOT NULL,
    Transaction_DateTime timestamp NOT NULL,
    Transaction_Store_ID serial NOT NULL,
    constraint fk_Customer_Card_ID foreign key (Customer_Card_ID) references Cards(Customer_Card_ID)
);

CREATE TABLE IF NOT EXISTS Checks
(
    Transaction_ID serial NOT NULL,
    SKU_ID serial NOT NULL,
    SKU_Amount numeric NOT NULL,
    SKU_Summ numeric NOT NULL,
    SKU_Summ_Paid numeric NOT NULL,
    SKU_Discount numeric NOT NULL,
    constraint fk_Transaction_ID foreign key (Transaction_ID) references Transactions(Transaction_ID),
    constraint fk_SKU_ID foreign key (SKU_ID) references Product_Grid(SKU_ID)
);

CREATE TABLE IF NOT EXISTS Date_of_Analysis
(
    Analysis_Formation timestamp NOT NULL
);

/* Раскоментить для загрузки мини-датасета */

CREATE OR REPLACE PROCEDURE
    csv_import(filepath text, delimiter char default E'\t')
    LANGUAGE plpgsql
AS
$$
BEGIN
    EXECUTE ('COPY personal_information FROM ''' || filepath || 'Personal_Data_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY cards FROM ''' || filepath || 'Cards_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY sku_group FROM ''' || filepath || 'Groups_SKU_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY product_grid FROM ''' || filepath || 'SKU_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY stores FROM ''' || filepath || 'Stores_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY transactions FROM ''' || filepath || 'Transactions_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY checks FROM ''' || filepath || 'Checks_Mini.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY date_of_analysis FROM ''' || filepath || 'Date_Of_Analysis_Formation.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
END
$$
;

CREATE OR REPLACE PROCEDURE
    csv_export(filepath text, delimiter char default E'\t')
    LANGUAGE plpgsql
AS
$$
BEGIN
    EXECUTE ('COPY personal_information TO ''' || filepath || 'Personal_Data_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY cards TO ''' || filepath || 'Cards_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY sku_group TO ''' || filepath || 'Groups_SKU_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY product_grid TO ''' || filepath || 'SKU_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY stores TO ''' || filepath || 'Stores_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY transactions TO ''' || filepath || 'Transactions_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY checks TO ''' || filepath || 'Checks_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
    EXECUTE ('COPY date_of_analysis TO ''' || filepath || 'Date_Of_Analysis_Formation_out.tsv' ||
            ''' DELIMITER ''' || delimiter || '''CSV;');
END
$$
;

/* Раскоментить для загрузки полного датасета */
--
-- CREATE OR REPLACE PROCEDURE
--     csv_import(filepath text, delimiter char default E'\t')
--     LANGUAGE plpgsql
-- AS
-- $$
-- BEGIN
--     EXECUTE ('COPY personal_information FROM ''' || filepath || 'Personal_Data.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY cards FROM ''' || filepath || 'Cards.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY sku_group FROM ''' || filepath || 'Groups_SKU.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY product_grid FROM ''' || filepath || 'SKU.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY stores FROM ''' || filepath || 'Stores.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY transactions FROM ''' || filepath || 'Transactions.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY checks FROM ''' || filepath || 'Checks.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
--     EXECUTE ('COPY date_of_analysis FROM ''' || filepath || 'Date_Of_Analysis_Formation.tsv' ||
--             ''' DELIMITER ''' || delimiter || '''CSV;');
-- END
-- $$
-- ;

-- Алекс
--  CALL csv_import('/home/sadeteen/s21/SQL/SQL3_RetailAnalitycs_v1.0-1/datasets/', E'\t');

-- Саша
-- CALL csv_import('/tmp/retail/', E'\t');

-- Гульназ
CALL csv_import('/mnt/c/Users/Gulnaz Vildanova/Documents/SQL3_RetailAnalitycs_v1.0-1/datasets/', E'\t');
