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



CREATE OR REPLACE FUNCTION fnc_round_in_increments_of_5(group_minimum_discount numeric)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE RES numeric := 0;
BEGIN
        FOR i IN 5..100 BY 5 LOOP
            CASE WHEN (i >= group_minimum_discount)
            THEN 
                res := i;  
                exit;
            ELSE res := 0;
            END case;
       END LOOP;
       RETURN res;
END;
$$;

-- SELECT * from fnc_round_in_increments_of_5(1.01);
-- SELECT customer_id,group_id, group_minimum_discount, fnc_round_in_increments_of_5(g.group_minimum_discount) as round
-- from groups g 
-- ORDER BY customer_id,group_id;
















DROP FUNCTION IF EXISTS fnc_loop (max_churn_index numeric, max_share numeric, margin_share NUMERIC);
CREATE OR REPLACE FUNCTION fnc_loop(max_churn_index numeric, max_share numeric, margin_share NUMERIC)
RETURNS TABLE (
    customer_id INTEGER
    -- group_id INTEGER,
    -- group_affinity_index NUMERIC,
    -- group_churn_rate NUMERIC,
    -- group_discount_share NUMERIC
    -- Group_Name varchar,
    -- group_margin NUMERIC,
    -- shag5 NUMERIC,
    -- group_minimum_discount__ NUMERIC,
    -- ceil2 NUMERIC,
    -- Offer_Discount_Depth NUMERIC
)
LANGUAGE plpgsql
AS $$
DECLARE Offer_Discount_Depth numeric := 0;
BEGIN

    --    LOOP
    --     RETURN QUERY(
    --         SELECT gr.customer_id FROM groups gr
    --         where gr.customer_id = 1
    --     );
    --    END LOOP;
     for variable in 1..10 by 2 loop
  raise notice 'Iteration = %', variable;
  end loop;
    -- IF (ceil2 < shag5) 
    -- THEN Offer_Discount_Depth := ceil2;
    -- ELSE quit;
    -- END IF; 
    --    RETURN Offer_Discount_Depth;
END;
$$;

-- SELECT * from fnc_loop(3,70,30);


























DROP FUNCTION IF EXISTS fnc_offer_group;
CREATE OR REPLACE FUNCTION fnc_offer_group (max_churn_index numeric, max_share numeric, margin_share NUMERIC)
RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    group_affinity_index NUMERIC,
    group_churn_rate NUMERIC,
    group_discount_share NUMERIC,
    -- Group_Name varchar,
    -- group_margin NUMERIC,
    shag5 NUMERIC,
    -- group_minimum_discount__ NUMERIC,
    ceil2 NUMERIC,
    Offer_Discount_Depth NUMERIC
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
                    g.group_discount_share,
                    ceil(f_avg.avg*margin_share/100) as shag5,
                    fnc_round_in_increments_of_5(g.group_minimum_discount) as ceil2
                from groups g
                LEFT JOIN fnc_avg_group_margin() as f_avg ON f_avg.customer_id = g.customer_id AND f_avg.group_id = g.group_id
                -- WHERE shag5 < 0 
                group by g.customer_id, g.group_id, g.group_affinity_index, g.group_churn_rate, g.group_discount_share,g.group_margin, g.group_minimum_discount, f_avg.avg
                HAVING g.group_churn_rate < max_churn_index AND g.group_discount_share < (max_share/100) 
                order by g.customer_id, g.group_affinity_index DESC),
            dat_group as (
                select dat.customer_id, MAX(dat.group_affinity_index)
                from personal_information pi
                full join dat on dat.customer_id = pi.customer_id
                GROUP BY dat.customer_id
                order by dat.customer_id
            ),
            dat_l as (
                SELECT dat.customer_id, g.group_id, dat.group_affinity_index,g.group_churn_rate, g.group_discount_share, sg.group_name,
                    -- g.group_margin::NUMERIC,
                    -- ceil(g.group_margin::NUMERIC*(margin_share/100)) as shag5,
                    ceil(g.group_margin::NUMERIC*(margin_share/100)) as shag5,
                    -- g.group_minimum_discount,
                    -- ceil((g.group_minimum_discount * 100 / 5) * 5) as ceil2
                    fnc_round_in_increments_of_5(g.group_minimum_discount)
                from dat  
                left join groups g on g.customer_id = dat.customer_id AND g.group_id = dat.group_id
                left join sku_group sg on sg.group_id = g.group_id
                where g.group_affinity_index = (select MAX(d.group_affinity_index) from dat d where d.customer_id = dat.customer_id) 
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


        -- SELECT dat.customer_id, g.group_id, dat.group_affinity_index,g.group_churn_rate, g.group_discount_share, sg.group_name,
        --         -- g.group_margin::NUMERIC,
        --         -- ceil(g.group_margin::NUMERIC*(margin_share/100)) as shag5,
        --         ceil(g.group_margin::NUMERIC*(margin_share/100)) as shag5,
        --         -- g.group_minimum_discount,
        --         -- ceil((g.group_minimum_discount * 100 / 5) * 5) as ceil2
        --         -- fnc_loop()::NUMERIC,
        --         fnc_round_in_increments_of_5(g.group_minimum_discount)
        -- from dat  
        -- left join groups g on g.customer_id = dat.customer_id AND g.group_id = dat.group_id
        -- left join sku_group sg on sg.group_id = g.group_id
        -- where g.group_affinity_index = (select MAX(d.group_affinity_index) from dat d where d.customer_id = dat.customer_id) 


        select dat.customer_id,
                dat.group_id,
                (dat.group_affinity_index),   
                dat.group_churn_rate,
                dat.group_discount_share,
                dat.shag5::NUMERIC,
                dat.ceil2,
                -- fnc_loop(dat.ceil2, dat.shag5::NUMERIC) as Offer_Discount_Depth
                dat.ceil2 as Offer_Discount_Depth
        from dat
        WHERE dat.shag5 > 0 AND dat.ceil2 > dat.shag5 AND dat.group_affinity_index = (SELECT MAX(d.group_affinity_index) FROM dat d WHERE d.customer_id = dat.customer_id)

        -- FOR customer_id IN SELECT customer_id from dat_l LOOP
        -- RAISE   NOTICE 'Customer: %; group: %',   customer_id, group_name;
        -- END LOOP;


    );
END;
$$ LANGUAGE plpgsql;

-- SELECT * from fnc_offer_group(3,70,30);



CREATE OR REPLACE FUNCTION fnc_avg_group_margin()
RETURNS TABLE (
        customer_id INTEGER,
        group_id INTEGER,
        avg NUMERIC
)
AS
$$
BEGIN 
    RETURN QUERY (
        SELECT ph.customer_id, ph.group_id, AVG(group_summ_paid-group_cost)
        from purchase_history ph
        GROUP by ph.customer_id, ph.group_id
        order by ph.customer_id, ph.group_id
    );
END;
$$ LANGUAGE plpgsql;

-- SELECT * FROM fnc_avg_group_margin();
















/*  ALL DATA  */
SET datestyle = DMY;
DROP FUNCTION IF EXISTS fnc_personal_offers_increasing_frequency_of_visits (
    first_day TIMESTAMP, 
    last_day TIMESTAMP, 
    trunsuction_number INT, 
    max_churn_index NUMERIC, 
    max_share NUMERIC, 
    margin_share NUMERIC);


CREATE OR REPLACE FUNCTION fnc_personal_offers_increasing_frequency_of_visits (
    first_day TIMESTAMP, 
    last_day TIMESTAMP, 
    trunsuction_number INT, 
    max_churn_index NUMERIC, 
    max_share NUMERIC, 
    margin_share NUMERIC)
RETURNS TABLE (
    customer_id INTEGER,
    group_id INTEGER,
    group_affinity_index NUMERIC, -- Индекс востребованности группы (максимальная)
    group_churn_rate NUMERIC, -- Индекс оттока (не больше заданного max_churn_index)
    group_discount_share NUMERIC, -- Доля транзакций со скидкой (не больше заданного max_share)
    avg NUMERIC, --  средняя маржа клиента по группе.
    shag5 NUMERIC,
    group_minimum_discount__ NUMERIC, -- минимальная скидка
    round_min_discount NUMERIC, -- округленная минимальная скидка
    Depth NUMERIC -- Максимальная глубина скидки
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
                    g.group_discount_share,
                    f_avg.avg,
                    ceil(f_avg.avg*margin_share/100) as shag5,
                    g.group_minimum_discount,
                    fnc_round_in_increments_of_5(g.group_minimum_discount) as round_min_discount
                from groups g
                LEFT JOIN fnc_avg_group_margin() as f_avg ON f_avg.customer_id = g.customer_id AND f_avg.group_id = g.group_id
                group by g.customer_id, g.group_id, g.group_affinity_index, g.group_churn_rate, g.group_discount_share,g.group_margin, g.group_minimum_discount, f_avg.avg
                HAVING g.group_churn_rate < max_churn_index AND g.group_discount_share < (max_share/100) 
                order by g.customer_id, g.group_affinity_index DESC)

        select dat.customer_id,
                dat.group_id,
                (dat.group_affinity_index),   
                dat.group_churn_rate,
                dat.group_discount_share,
                dat.avg,
                dat.shag5::NUMERIC,
                dat.group_minimum_discount,
                dat.round_min_discount,
                dat.round_min_discount as depth
        from dat
        -- LEFT JOIN customers c ON c.customer_id = dat.customer_id
        -- LEFT JOIN sku_group sg ON sg.group_id = dat.group_id
        -- WHERE dat.shag5 > 0 AND dat.round_min_discount > dat.shag5 AND dat.group_affinity_index = (SELECT MAX(d.group_affinity_index) FROM dat d WHERE d.customer_id = dat.customer_id)
    );
END;
$$ LANGUAGE plpgsql;

SELECT * from fnc_personal_offers_increasing_frequency_of_visits('18.08.2022 00:00:00', '18.08.2022 00:00:00', 1, 3, 50, 30);































































/*  ЧУЖАЯ РАБОТА ДЛЯ ВДОХНОВЕНИЯ  */


-- -- функция возвращает таблицу для формирование персональных предложений,
-- -- ориентированных на рост частоты визитов
-- CREATE OR REPLACE FUNCTION get_offers_frequency_of_visits(
--     t_start_date timestamp DEFAULT '2022-01-01', -- первая дата периода
--     t_end_date timestamp DEFAULT '2022-12-31', -- последняя дата периода
--     add_transactions_count int DEFAULT 1, -- добавляемое число транзакций
--     max_churn_rate numeric DEFAULT 100, -- максимальный индекс оттока
--     max_discount_share numeric DEFAULT 100, -- максимальная доля транзакций со скидкой (в процентах)
--     margin_part numeric DEFAULT 50) -- допустимая доля маржи (в процентах)
-- RETURNS table
--     (customer_id bigint, -- Идентификатор клиента
--     start_date timestamp, -- Дата начала периода
--     end_date timestamp, -- Дата окончания периода
--     required_transactions_count int, -- Целевое количество транзакций
--     group_name varchar, -- Группа предложения
--     offer_discount_depth int) -- Максимальная глубина скидки
-- LANGUAGE plpgsql
-- AS $$
-- DECLARE
--     days_count numeric;
-- BEGIN
--     IF t_start_date > t_end_date THEN
--         RAISE EXCEPTION 'ERROR: Дата начала должна быть меньше даты окончания периода';
--     END IF;
-- days_count := get_diff_between_date_in_days(t_end_date, t_start_date);

-- RETURN QUERY
--     SELECT DISTINCT
--         g.customer_id,
--         t_start_date,
--         t_end_date,
--         round(days_count / (SELECT customer_frequency FROM customers c WHERE c.customer_id = g.customer_id))::int + add_transactions_count,
--         first_value(gs.group_name) OVER w,
--         (first_value(g.group_minimum_discount) OVER w * 100)::int / 5 * 5 + 5
--     FROM groups g
--     JOIN groups_sku gs ON gs.group_id = g.group_id
--         AND g.group_churn_rate <= max_churn_rate
--         AND g.group_discount_share * 100 < max_discount_share
--         AND (g.group_minimum_discount * 100)::int / 5 * 5 + 5
--              < (SELECT sum(s2.sku_retail_price - s2.sku_purchase_price) / sum(s2.sku_retail_price)
--                 FROM sku s
--                 JOIN stores s2 ON g.group_id = s.group_id
--                     AND s.sku_id = s2.sku_id) * margin_part
--         WINDOW w as (PARTITION BY g.customer_id ORDER BY g.group_affinity_index DESC);
-- END $$;




-- ------------- ТЕСТОВЫЕ ЗАПРОСЫ -------------


-- SELECT * FROM get_offers_frequency_of_visits();

-- SELECT * FROM get_offers_frequency_of_visits('2022-08-18 00:00:00', '2022-08-18 00:00:00',
--     1,3, 70, 30);

-- SELECT * FROM get_offers_frequency_of_visits('2022-08-18 00:00:00', '2022-08-18 00:00:00',
--     1,10, 50, 50);


