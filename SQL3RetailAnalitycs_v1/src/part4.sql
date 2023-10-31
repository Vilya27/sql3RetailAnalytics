DROP FUNCTION IF EXISTS fnc_avg_check_in_period CASCADE;
DROP FUNCTION IF EXISTS fnc_avg_check_num_transactions CASCADE;
DROP FUNCTION IF EXISTS fnc_reward_group CASCADE;
DROP FUNCTION IF EXISTS fnc_personal_offers CASCADE;

CREATE OR REPLACE FUNCTION fnc_avg_check_in_period(date_begin DATE DEFAULT '2015-01-31',
                                                   date_end DATE DEFAULT '2022-08-22')
    RETURNS TABLE
            (
                Customer_ID   INTEGER,
                Average_check NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        (SELECT pi.customer_id, (SUM(t.transaction_summ) / COUNT(t.transaction_id))
         FROM cards c
                  JOIN personal_information pi ON pi.customer_id = c.customer_id
                  JOIN transactions t ON t.customer_card_id = c.customer_card_id
         WHERE t.transaction_datetime BETWEEN date_begin AND date_end
         GROUP BY pi.customer_id);
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fnc_avg_check_num_transactions(num_transactions INT)
    RETURNS TABLE
            (
                Customer_ID   INTEGER,
                Average_check NUMERIC
            )
AS
$$
BEGIN
    RETURN QUERY
        (with last_tr AS (SELECT pi.customer_id, (SUM(tmp.transaction_summ) / COUNT(tmp.rn)) AS sum, rn
                          FROM personal_information pi
                                   JOIN (SELECT p.customer_id,
                                                ROW_NUMBER()
                                                OVER (PARTITION BY p.customer_id ORDER BY t2.transaction_datetime DESC) AS rn,
                                                t2.transaction_summ
                                         FROM personal_information p
                                                  JOIN cards c2 ON p.customer_id = c2.customer_id
                                                  JOIN transactions t2 ON c2.customer_card_id = t2.customer_card_id
                                         GROUP BY p.customer_id, t2.transaction_datetime, t2.transaction_summ) tmp
                                        ON tmp.customer_id = pi.customer_id
                          WHERE tmp.rn <= num_transactions
                          GROUP BY pi.customer_id, rn)

         SELECT last_tr.customer_id, SUM(sum) / COUNT(rn)
         FROM last_tr
         GROUP BY last_tr.customer_id);
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fnc_reward_group(in_max_churn_index NUMERIC,
                                            in_max_share_of_transactions NUMERIC,
                                            in_margin_share NUMERIC)
    RETURNS TABLE
            (
                Customer_ID    INTEGER,
                Group_name     VARCHAR,
                Discount_depth NUMERIC
            )
    LANGUAGE plpgsql
AS
$$
BEGIN
    RETURN QUERY
        WITH tmp AS (SELECT DISTINCT td.customer_id,
                                     pg.group_id,
                                     sg.group_name,
                                     groups.group_affinity_index,
                                     (CEIL((group_minimum_discount * 100) / 5) * 5) AS discount
                     FROM _total_data td
                              JOIN stores s ON s.sku_id = td.sku_id
                              JOIN product_grid pg ON td.sku_id = pg.sku_id
                              JOIN sku_group sg on sg.group_id = pg.group_id
                              JOIN groups ON td.customer_id = groups.customer_id AND
                                             pg.group_id = groups.group_id
                     WHERE groups.group_minimum_discount > 0
                       AND groups.group_churn_rate < in_max_churn_index
                       AND groups.group_discount_share < (in_max_share_of_transactions::numeric / 100.0)
                       AND CEIL((group_minimum_discount * 100) / 5) * 5 <
                           ((sku_retail_price - s.sku_purchase_price) * in_margin_share /
                            s.sku_retail_price))
        SELECT tmp.customer_id, tmp.group_name, tmp.discount
        FROM tmp
        WHERE (tmp.customer_id, tmp.group_affinity_index) IN
              (SELECT tmp.customer_id, MAX(tmp.group_affinity_index) FROM tmp GROUP BY tmp.customer_id)
        ORDER BY Customer_ID;
END;
$$;

CREATE OR REPLACE FUNCTION fnc_personal_offers(method INTEGER,
                                               date_begin DATE,
                                               date_end DATE,
                                               num_transactions INTEGER,
                                               coef_avg_check_gain NUMERIC,
                                               max_churn_index NUMERIC,
                                               max_share_discount_transactions NUMERIC,
                                               allowable_margin_share NUMERIC)
    RETURNS TABLE
            (
                Customer_ID            INTEGER,
                Required_Check_Measure NUMERIC,
                Group_Name             VARCHAR,
                Offer_Discount_Depth   NUMERIC
            )
AS
$$
DECLARE
    check_date_begin DATE := (SELECT MAX(transaction_datetime)
                              FROM transactions);
    check_last_date  DATE := (SELECT MIN(transaction_datetime)
                              FROM transactions);
BEGIN
    IF (method = 1) THEN
        IF date_begin > date_end THEN
            RAISE EXCEPTION 'First date (%) must be less than last date (%)', date_begin, date_end;
        ELSEIF date_begin > check_date_begin THEN
            date_begin := check_date_begin;
        ELSEIF
            date_end < check_last_date THEN
            date_end := check_last_date;
        END IF;
        RETURN QUERY (SELECT pi.customer_id,
                             facip.Average_check * coef_avg_check_gain,
                             frg.Group_name,
                             frg.Discount_depth
                      FROM personal_information pi
                               JOIN
                           fnc_avg_check_in_period(date_begin, date_end) facip ON pi.customer_id = facip.Customer_ID
                               JOIN fnc_reward_group(max_churn_index, max_share_discount_transactions,
                                                     allowable_margin_share) frg
                                    ON pi.customer_id = frg.Customer_ID);
    ELSEIF
        (method = 2) THEN
        RETURN QUERY (SELECT pi.customer_id,
                             facnt.Average_check * coef_avg_check_gain,
                             frg.Group_name,
                             frg.Discount_depth
                      FROM personal_information pi
                               JOIN
                           fnc_avg_check_num_transactions(num_transactions) facnt
                           ON pi.customer_id = facnt.Customer_ID
                               JOIN fnc_reward_group(max_churn_index, max_share_discount_transactions,
                                                     allowable_margin_share) frg
                                    ON pi.customer_id = frg.Customer_ID);
    END IF;
END;
$$ LANGUAGE plpgsql;

/*
SELECT *
FROM fnc_personal_offers(1, '2021-01-01',
                         '2022-12-31',
                         5,
                         1.15,
                         8,
                         70,
                         30);
 */

SELECT *
FROM fnc_personal_offers(2, NULL,
                         NULL,
                         100,
                         1.15,
                         3,
                         70,
                         30);
