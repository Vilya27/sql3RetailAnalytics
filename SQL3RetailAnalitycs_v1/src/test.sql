/* part3*/
-- SELECT current_user, session_user;
-- set role ... ;
-- reset role;
-- \du \dp \dn+ \d \c \c-mort 

-- create user Administrator;
-- create user Visitor;

-- select t.*, c.*, p.customer_id, p.customer_name
-- create view purchase_history as 


/* part2_purchase_history */

-- DROP VIEW IF EXISTS purchase_history;

-- create view purchase_history as




-- with pop as (
--     select p.customer_id, t.transaction_id, t.transaction_datetime, pg.group_id
--     from transactions t
--     full join cards c on t.customer_card_id = c.customer_card_id
--     full join personal_information p on c.customer_id = p.customer_id
--     full join checks ch on ch.transaction_id = t.transaction_id
--     full join product_grid pg on pg.sku_id = ch.sku_id
--     group by p.customer_id, t.transaction_id, pg.group_id
--     order by p.customer_id, t.transaction_id, pg.group_id
--     )
--     ,
--     pop2 as (
--     select *
--     from pop
--     join checks ch on ch.transaction_id = pop.transaction_id
--     -- join stores s on s.sku_id = ch.sku_id
--     )
-- -- select DISTINCT(customer_id), COUNT(customer_id)
-- -- select customer_id,group_id, COUNT(group_id)
-- -- select *
-- -- from pop
-- -- full join checks c on 
-- -- -- from transaions t
-- -- -- group by customer_id
-- -- group by customer_id, group_id
-- -- order by customer_id, group_id

--     select p.customer_id, t.transaction_id, t.transaction_datetime, pg.group_id, SUM(ch.sku_amount*s.sku_purchase_price) as group_cost  ,SUM(ch.sku_summ) as group_summ, SUM(ch.sku_summ_paid) as group_summ_paid
--     -- ch.sku_id, ,s.transaction_store_id
--     --  COUNT(pg.group_id), SUM(ch.sku_amount), SUM() OVER ()
--     from transactions t
--     full join cards c on t.customer_card_id = c.customer_card_id
--     full join personal_information p on c.customer_id = p.customer_id
--     full join checks ch on ch.transaction_id = t.transaction_id
--     full join product_grid pg on pg.sku_id = ch.sku_id
--     full join stores s on s.sku_id = ch.sku_id AND s.transaction_store_id = t.transaction_store_id
--     group by p.customer_id, t.transaction_id, pg.group_id
--     -- , ch.sku_id, s.transaction_store_id
--     order by p.customer_id, t.transaction_id, pg.group_id


-- -- select DISTINCT(customer_id), COUNT(customer_id)
-- -- -- select *
-- -- from pop
-- -- -- from transaions t
-- -- group by customer_id
-- -- -- order by customer_id, transaction_id, group_id




/*  part5  */

-- DROP FUNCTION IF EXISTS fnc_offer_group;
-- CREATE OR REPLACE FUNCTION fnc_offer_group (margin_share NUMERIC)
-- RETURNS TABLE (
--     customer_id INTEGER,
--     group_affinity_index NUMERIC,
--     Group_Name VARCHAR,
--     margin_sha NUMERIC
-- )
-- AS
-- $$
-- BEGIN 
--     RETURN QUERY (
--         SELECT pi.customer_id, 
--             g.group_affinity_index, 
--             FIRST_VALUE(sg.group_name) OVER (PARTITION BY pi.customer_id, g.group_affinity_index ORDER BY pi.customer_id, g.group_affinity_index DESC) as Group_Name, 
--             ceil(g.group_margin::NUMERIC*(margin_share::NUMERIC/100)) as max_
--             -- round(g.group_margin::NUMERIC, 1) as margin_sha
--             -- group_minimum_discount
--         FROM personal_information pi
--         FULL JOIN groups g ON g.customer_id = pi.customer_id
--         FULL JOIN sku_group sg ON sg.group_id = g.group_id
--         WHERE group_churn_rate < 5 AND group_discount_share < 0.5
--     );
-- END;
-- $$ LANGUAGE plpgsql;

-- SELECT * from fnc_offer_group(30);













-- SELECT c.customer_id, c.customer_frequency, ceil((date '2001-10-01' - date '2001-09-28')/c.customer_frequency)+1000 as Required_Transactions_Count 
-- FROM customers c;

-- SELECT customer_id, group_affinity_index from groups
-- WHERE group_churn_rate < 5 AND group_discount_share < 0.5
-- GROUP by customer_id, group_affinity_index
-- ORDER BY customer_id, group_affinity_index DESC





-- SELECT pi.customer_id, g.group_affinity_index, FIRST_VALUE(sg.group_name) OVER (PARTITION BY pi.customer_id, group_affinity_index ORDER BY pi.customer_id, group_affinity_index DESC)
-- FROM personal_information pi
-- FULL JOIN groups g ON g.customer_id = pi.customer_id
-- FULL JOIN sku_group sg ON sg.group_id = g.group_id
-- WHERE group_churn_rate < 5 AND group_discount_share < 0.5
-- GROUP by c.customer_id, group_affinity_index
-- ORDER BY c.customer_id, group_affinity_index DESC





-- DROP FUNCTION IF EXISTS fnc_personal_offers_frequency_of_visits;

-- CREATE OR REPLACE FUNCTION fnc_personal_offers_frequency_of_visits (
--     first_day TIMESTAMP, 
--     last_day TIMESTAMP, 
--     trunsuction_number INT, 
--     max_churn_index NUMERIC, 
--     max_share NUMERIC, 
--     margin_share NUMERIC)
-- RETURNS TABLE
--     (
--         Customer_ID INTEGER,
--         Start_Date TIMESTAMP,
--         End_Date TIMESTAMP,
--         Required_Transactions_Count NUMERIC,
--         Group_Name VARCHAR,
--         Offer_Discount_Depth NUMERIC
--     )
-- AS
-- $$
-- BEGIN
--     RETURN QUERY (
--         -- SELECT pi.customer_id, first_day, last_day, ceil( (first_day::DATE - last_day::DATE) / (nullif(c.customer_frequency,0)) +trunsuction_number) as Required_Transactions_Count, pi.customer_surname, c.customer_churn_rate
--         SELECT pi.customer_id, first_day, last_day, 
        -- ceil((first_day::DATE - last_day::DATE) / (c.customer_frequency) + trunsuction_number) as Required_Transactions_Count, pi.customer_surname, c.customer_churn_rate
--         FROM personal_information pi
--         FULL JOIN customers c ON pi.customer_id = c.customer_id
--         );
-- END;
-- $$ LANGUAGE plpgsql;


-- SELECT * FROM fnc_personal_offers_frequency_of_visits('18.08.2022 00:00:00', '18.08.2022 00:00:00', 1, 3, 70, 30);

DROP FUNCTION IF EXISTS fnc_offer_group;
CREATE OR REPLACE FUNCTION fnc_offer_group (max_churn_index numeric, max_share numeric, margin_share NUMERIC)
RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    group_affinity_index NUMERIC,
    group_churn_rate NUMERIC,
    group_discount_share NUMERIC
    -- Group_Name varchar
    -- max_ NUMERIC,
    -- group_minimum_discount NUMERIC,
    -- ceil1 NUMERIC,
    -- ceil2 NUMERIC
)
AS
$$
BEGIN 
    RETURN QUERY (
            with dat as (
                select g.customer_id,
                    g.group_id,
                    (g.group_affinity_index),   
                    g.group_churn_rate,
                    g.group_discount_share
                from groups g
                group by g.customer_id, g.group_id, g.group_affinity_index, g.group_churn_rate, g.group_discount_share
                HAVING g.group_churn_rate < max_churn_index AND g.group_discount_share < (max_share/100) 
                order by g.customer_id, g.group_affinity_index DESC),
            dat_group as (
                select dat.customer_id, MAX(dat.group_affinity_index)
                from personal_information pi
                full join dat on dat.customer_id = pi.customer_id
                GROUP BY dat.customer_id
                order by dat.customer_id
            )
            -- ,
            -- dat_gr as (
            --     SELECT
            --     from groups g
            --     where g.group_affinity_index = (select MAX(dat.group_affinity_index) from dat)

            -- )
        -- SELECT pi.customer_id, 
        --     g.group_affinity_index,
        --     g.group_churn_rate,
        --     g.group_discount_share,
        --     MAX(g.group_affinity_index) OVER (PARTITION BY pi.customer_id, g.group_affinity_index ORDER BY pi.customer_id, g.group_affinity_index DESC) as Group_Name, 
        --     ceil(g.group_margin::NUMERIC*(margin_share::NUMERIC/100)) as max_,
        --     g.group_minimum_discount,
        --     ceil((g.group_minimum_discount * 100 / 5) * 5),
        --     ceil(g.group_minimum_discount*20)/20
        -- FROM personal_information pi
        -- FULL JOIN groups g ON g.customer_id = pi.customer_id
        -- FULL JOIN sku_group sg ON sg.group_id = g.group_id
        -- WHERE g.group_churn_rate < max_churn_index AND g.group_discount_share < (max_share/100)

        -- SELECT dat_group.customer_id,
            -- sg.group_name
            -- ceil(g.group_margin::NUMERIC*(margin_share::NUMERIC/100)) as max_,
            -- g.group_minimum_discount,
            -- ceil((g.group_minimum_discount * 100 / 5) * 5),
            -- ceil(g.group_minimum_discount*20)/20
        -- FROM dat_group
        -- left JOIN groups g ON g.customer_id = dat_group.customer_id
        -- left JOIN sku_group sg ON sg.group_id = g.group_id

        -- select * from dat


        SELECT dat.customer_id, dat.group_affinity_index, sg.group_name
        from dat  
        left join groups g on g.customer_id = dat.customer_id AND g.group_id = dat.group_id
        left join sku_group sg on sg.group_id = g.group_id
        where g.group_affinity_index = (select MAX(d.group_affinity_index) from dat d where d.customer_id = dat.customer_id) 

    );
END;
$$ LANGUAGE plpgsql;

SELECT * from fnc_offer_group(3,70,30);



-- SELECT 
-- SELECT round(20.2,5)
-- from personal_information