SET datestyle = DMY;
DROP FUNCTION IF EXISTS fnc_round_in_increments_of_5(group_minimum_discount NUMERIC);
DROP FUNCTION IF EXISTS fnc_avg_group_margin();
DROP FUNCTION IF EXISTS fnc_personal_offers_increasing_frequency_of_visits(first_day TIMESTAMP, last_day TIMESTAMP, trunsuction_number NUMERIC, max_churn_index NUMERIC, max_share NUMERIC, margin_share NUMERIC);


CREATE OR REPLACE FUNCTION fnc_round_in_increments_of_5(group_minimum_discount NUMERIC)
RETURNS numeric
LANGUAGE plpgsql
AS $$
DECLARE RES NUMERIC := 0;
BEGIN
        FOR i IN 5..100 BY 5 LOOP
            CASE WHEN (i >= group_minimum_discount)
            THEN 
                res := i;  
                exit;
            ELSE res := 0;
            END CASE;
       END LOOP;
       RETURN res;
END;
$$;


CREATE OR REPLACE FUNCTION fnc_avg_group_margin()
RETURNS TABLE (
        customer_id INTEGER,
        group_id INTEGER,
        avg NUMERIC)
AS
$$
BEGIN 
    RETURN QUERY (
        SELECT ph.customer_id, ph.group_id, AVG(group_summ_paid-group_cost)
        FROM purchase_history ph
        GROUP BY ph.customer_id, ph.group_id
        ORDER BY ph.customer_id, ph.group_id
    );
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fnc_personal_offers_increasing_frequency_of_visits (
    first_day TIMESTAMP, 
    last_day TIMESTAMP, 
    trunsuction_number NUMERIC, 
    max_churn_index NUMERIC, 
    max_share NUMERIC, 
    margin_share NUMERIC)
RETURNS TABLE (
    customer_id INTEGER,
    Start_Date TIMESTAMP, 
    End_Date TIMESTAMP,
    Required_Transactions_Count NUMERIC,
    Group_Name VARCHAR, 
    Offer_Discount_Depth NUMERIC)
AS
$$
BEGIN 
    RETURN QUERY (
            WITH dat AS (
                SELECT g.customer_id,
                    g.group_id,
                    g.group_affinity_index,   
                    g.group_churn_rate,
                    g.group_discount_share,
                    ceil(f_avg.avg*margin_share/100) AS max_allowable_discount,
                    fnc_round_in_increments_of_5(g.group_minimum_discount * 100) AS round_min_discount
                FROM groups g
                LEFT JOIN fnc_avg_group_margin() AS f_avg ON f_avg.customer_id = g.customer_id AND f_avg.group_id = g.group_id
                GROUP BY g.customer_id, g.group_id, g.group_affinity_index, g.group_churn_rate, g.group_discount_share,g.group_margin, g.group_minimum_discount, f_avg.avg
                HAVING g.group_churn_rate < max_churn_index AND g.group_discount_share < (max_share/100) 
                ORDER BY g.customer_id, g.group_affinity_index DESC)

        SELECT dat.customer_id,
                first_day,
                last_day,
                round(EXTRACT(day FROM (last_day - first_day)) / (c.customer_frequency)) + trunsuction_number AS Required_Transactions_Count,
                sg.group_name,
                dat.round_min_discount AS Offer_Discount_Depth
        FROM dat
        LEFT JOIN customers c ON c.customer_id = dat.customer_id
        LEFT JOIN sku_group sg ON sg.group_id = dat.group_id
        WHERE dat.max_allowable_discount > 0 AND dat.round_min_discount > dat.max_allowable_discount AND dat.group_affinity_index = (SELECT MAX(d.group_affinity_index) FROM dat d WHERE d.customer_id = dat.customer_id)
    );
END;
$$ LANGUAGE plpgsql;

SELECT * FROM fnc_personal_offers_increasing_frequency_of_visits('18.08.2022 00:00:00', '18.08.2022 00:00:00', 1, 3, 70, 30);
