DROP VIEW IF EXISTS _num_group_transactions, _total_group_transactions, _group_stability_index, _last_transactions, _pre_groups, _group_discounts CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "groups" CASCADE;
DROP FUNCTION IF EXISTS fnc_make_groups_view CASCADE;

CREATE VIEW _num_group_transactions AS
WITH data AS (SELECT DISTINCT p.customer_id,
                              p.group_id,
                              ph.transaction_id,
                              ph.transaction_datetime,
                              ROW_NUMBER()
                              OVER (PARTITION BY p.customer_id, p.group_id ORDER BY ph.transaction_id) AS count_group_transactions,
                              EXTRACT(EPOCH FROM ((SELECT MAX(analysis_formation) FROM date_of_analysis) -
                                                  last_group_purchase_date)) / 60 / 60 /
                              24                                                                       AS days_since_last_group_buy,
                              p.group_frequency,
                              ph.group_summ_paid - ph.group_cost                                       AS group_margin
              FROM purchase_history ph
                       LEFT JOIN periods p ON ph.customer_id = p.customer_id AND ph.group_id = p.group_id
              GROUP BY p.customer_id, p.group_id, ph.transaction_id, ph.transaction_datetime,
                       first_group_purchase_date,
                       last_group_purchase_date, p.group_frequency, ph.group_summ_paid, ph.group_cost)
SELECT DISTINCT data.customer_id,
                data.group_id,
                data.transaction_id,
                data.transaction_datetime,
                MAX(count_group_transactions)
                OVER (PARTITION BY data.customer_id, data.group_id)            AS num_group_transactions,
                data.days_since_last_group_buy,
                data.group_frequency,
                data.days_since_last_group_buy::numeric / data.group_frequency AS group_churn_rate,
                data.group_margin
FROM data
GROUP BY data.customer_id, data.group_id, data.transaction_id, data.transaction_datetime, count_group_transactions,
         data.days_since_last_group_buy, data.group_frequency, data.group_margin
ORDER BY 1, 2, 3;

CREATE VIEW _total_group_transactions AS
WITH data AS (SELECT DISTINCT p.customer_id,
                              p.group_id,
                              transaction_id,
                              transaction_datetime,
                              first_group_purchase_date,
                              last_group_purchase_date,
                              array_agg(transaction_id)
                              FILTER (WHERE transaction_datetime BETWEEN first_group_purchase_date AND last_group_purchase_date)
                                  OVER (PARTITION BY p.customer_id, p.group_id) AS all_group_transactions_array
              FROM purchase_history ph
                       LEFT JOIN periods p ON ph.customer_id = p.customer_id
              GROUP BY p.customer_id, p.group_id, transaction_id, transaction_datetime,
                       first_group_purchase_date,
                       last_group_purchase_date)
SELECT DISTINCT customer_id,
                group_id,
                transaction_id,
                transaction_datetime,
                first_group_purchase_date,
                last_group_purchase_date,
                (SELECT count(*)
                 FROM (SELECT DISTINCT unnest(all_group_transactions_array)) agta) AS group_buy_in_period,
                all_group_transactions_array
FROM data
GROUP BY customer_id, group_id, transaction_id, transaction_datetime, first_group_purchase_date,
         last_group_purchase_date, group_buy_in_period,
         all_group_transactions_array
ORDER BY 1, 2, 3;

CREATE VIEW _group_stability_index AS
WITH data AS (SELECT DISTINCT ph.customer_id,
                              ph.group_id,
                              ph.transaction_id,
                              ph.transaction_datetime,
                              COUNT(ph.transaction_datetime)
                              OVER (PARTITION BY ph.customer_id, ph.group_id)                               AS num_of_transactions,
                              ROW_NUMBER()
                              OVER (PARTITION BY ph.customer_id, ph.group_id ORDER BY transaction_datetime) AS count_group_transactions,
                              EXTRACT(EPOCH FROM (ph.transaction_datetime -
                                                  LAG(ph.transaction_datetime) OVER (ORDER BY ph.customer_id,
                                                      ph.group_id, ph.transaction_datetime))) / 60 / 60 /
                              24                                                                            AS transaction_period,
                              p.group_frequency
              FROM purchase_history ph
                       LEFT JOIN periods p ON ph.customer_id = p.customer_id AND ph.group_id = p.group_id
              GROUP BY ph.customer_id, ph.group_id, ph.transaction_id, ph.transaction_datetime, p.group_frequency)
SELECT *,
       AVG(relative_difference) OVER (PARTITION BY customer_id, group_id) AS group_stability_index
FROM (SELECT DISTINCT customer_id,
                      group_id,
                      transaction_id,
                      transaction_datetime,
                      num_of_transactions,
                      count_group_transactions,
                      CASE
                          WHEN num_of_transactions = 1 THEN 0
                          WHEN count_group_transactions = 1 THEN NULL
                          ELSE transaction_period
                          END AS transaction_period,
                      group_frequency,
                      CASE
                          WHEN num_of_transactions = 1 THEN 0
                          WHEN count_group_transactions = 1 THEN NULL
                          ELSE ABS(transaction_period - group_frequency)
                          END AS abs_difference,
                      CASE
                          WHEN num_of_transactions = 1 THEN 1
                          WHEN count_group_transactions = 1 THEN NULL
                          ELSE ABS(transaction_period - group_frequency)::numeric / group_frequency
                          END AS relative_difference
      FROM data
      GROUP BY customer_id, group_id, transaction_id, transaction_datetime, transaction_period, group_frequency,
               num_of_transactions, count_group_transactions
      ORDER BY 1, 2, 4) AS X
WHERE transaction_period IS NOT NULL;

CREATE VIEW _last_transactions AS
SELECT ngt.transaction_id,
       ngt.transaction_datetime,
       row_number() OVER (ORDER BY ngt.transaction_datetime DESC) AS global_transaction_num
FROM _num_group_transactions ngt
WHERE ngt.transaction_id IS NOT NULL
GROUP BY transaction_id, ngt.customer_id, ngt.transaction_datetime;


CREATE VIEW _group_discounts AS
WITH data AS (SELECT td.customer_id                                      AS cust_id,
                     pg.group_id                                         AS gr_id,
                     td.transaction_id                                   AS transaction_id,
                     td.sku_discount::numeric / td.sku_summ              AS dicsount_percent,
                     array_agg(td.transaction_id)
                     OVER (PARTITION BY td.customer_id, pg.group_id)     AS total_num_group_buys_array,
                     array_agg(td.transaction_id)
                     FILTER ( WHERE td.sku_discount::numeric / td.sku_summ > 0)
                         OVER (PARTITION BY td.customer_id, pg.group_id) AS num_dicsount_buys_array,
                     MIN(td.sku_discount::numeric / td.sku_summ)
                     OVER (PARTITION BY pg.group_id, td.customer_id)     AS min_dicsount_percent,
                     ph.group_summ_paid,
                     ph.group_summ,
                     SUM(ph.group_summ_paid)
                     FILTER ( WHERE ph.group_summ - ph.group_summ_paid > 0 )
                         OVER (PARTITION BY td.customer_id, pg.group_id) AS total_group_summ_paid,
                     SUM(ph.group_summ)
                     FILTER ( WHERE ph.group_summ - ph.group_summ_paid > 0 )
                         OVER (PARTITION BY td.customer_id, pg.group_id) AS total_group_summ
              FROM _total_data td
                       FULL JOIN product_grid pg ON td.sku_id = pg.sku_id
                       FULL JOIN (SELECT DISTINCT customer_id, group_id, group_summ_paid, group_summ
                                  FROM purchase_history) ph
                                 on td.customer_id = ph.customer_id AND pg.group_id = ph.group_id
              GROUP BY td.customer_id, pg.group_id, td.sku_discount, td.sku_summ, td.transaction_id, ph.group_summ_paid,
                       ph.group_summ
              ORDER BY 1, 2)
SELECT *,
       (SELECT count(*)
        FROM (SELECT DISTINCT unnest(total_num_group_buys_array)) tngba) AS total_num_group_buys,
       (SELECT count(*)
        FROM (SELECT DISTINCT unnest(num_dicsount_buys_array)) tngba)    AS num_dicsount_buys,
       total_group_summ_paid / total_group_summ                          AS group_average_discount
FROM data;


CREATE OR REPLACE FUNCTION fnc_make_groups_view(IN method INT DEFAULT 1,
                                                IN num_days INTERVAL DEFAULT '3650 days'::interval,
                                                IN num_transactions INT DEFAULT 10000)
    RETURNS TABLE
            (
                customer_id           INTEGER,
                group_id              INTEGER,
                group_affinity_index  NUMERIC,
                group_churn_rate      NUMERIC,
                group_stability_index NUMERIC,
                group_margin          DOUBLE PRECISION
            )
AS
$$
BEGIN
    IF $1 = 1 THEN
        RAISE NOTICE 'Given parameters:
         Method 1 chosen
         Days from analysis date: %', $2;
    ELSEIF $1 = 2 THEN
        RAISE NOTICE 'Given parameters:
         Method 2 chosen
         Nums of transactions: %', $3;
    ELSE
        RAISE EXCEPTION 'Incorrect method chosen: %', $1
            USING HINT = 'Choose 1 or 2 as first parameter - method';
    END IF;
    RETURN QUERY
        SELECT DISTINCT pi.customer_id,
                        pg.group_id,
                        ngt.num_group_transactions::numeric / tgt.group_buy_in_period AS group_affinity_index,
                        ngt.group_churn_rate,
                        gsi.group_stability_index,
                        COALESCE(CASE
                                     WHEN ($1 = 1) THEN
                                                     SUM(ngt.group_margin::numeric)
                                                     FILTER (WHERE ngt.transaction_datetime BETWEEN (SELECT analysis_formation FROM date_of_analysis) - $2 AND
                                                             (SELECT analysis_formation FROM date_of_analysis) )
                                                         OVER (PARTITION BY ngt.customer_id, ngt.group_id) /
                                                     SQRT(COUNT(ngt.group_margin::numeric)
                                                          FILTER (WHERE ngt.transaction_datetime BETWEEN (SELECT analysis_formation FROM date_of_analysis) - $2 AND
                                                                  (SELECT analysis_formation FROM date_of_analysis) )
                                                              OVER (PARTITION BY ngt.customer_id, ngt.group_id))
                                     WHEN ($1 = 2) THEN
                                                     SUM(ngt.group_margin::numeric)
                                                     FILTER (WHERE lt.global_transaction_num <= $3 )
                                                         OVER (PARTITION BY ngt.customer_id, ngt.group_id) /
                                                     SQRT(COUNT(ngt.group_margin::numeric)
                                                          FILTER (WHERE lt.global_transaction_num <= $3 )
                                                              OVER (PARTITION BY ngt.customer_id, ngt.group_id))
                                     END, 0)                                          AS group_margin
        FROM personal_information pi
                 FULL JOIN cards c on pi.customer_id = c.customer_id
                 FULL JOIN transactions t on c.customer_card_id = t.customer_card_id
                 FULL JOIN checks c2 on t.transaction_id = c2.transaction_id
                 FULL JOIN product_grid pg on c2.sku_id = pg.sku_id
                 FULL JOIN _num_group_transactions ngt
                           on pi.customer_id = ngt.customer_id AND pg.group_id = ngt.group_id
                 FULL JOIN _total_group_transactions tgt
                           on pi.customer_id = tgt.customer_id AND pg.group_id = tgt.group_id
                 FULL JOIN _group_stability_index gsi on pi.customer_id = gsi.customer_id AND pg.group_id = gsi.group_id
                 FULL JOIN _last_transactions lt on c2.transaction_id = lt.transaction_id
        WHERE pi.customer_id IS NOT NULL
        GROUP BY pi.customer_id, pg.group_id, ngt.num_group_transactions, tgt.group_buy_in_period, ngt.group_churn_rate,
                 gsi.group_stability_index, ngt.group_margin, ngt.transaction_datetime, ngt.customer_id, ngt.group_id,
                 lt.global_transaction_num
        ORDER BY 1, 2;
END
$$ LANGUAGE plpgsql;

CREATE VIEW _pre_groups AS
SELECT *
FROM fnc_make_groups_view(1, '3650 days', 10000);

CREATE MATERIALIZED VIEW "groups" AS
SELECT pg2.customer_id,
       pg2.group_id,
       pg2.group_affinity_index,
       pg2.group_churn_rate,
       pg2.group_stability_index,
       pg2.group_margin,
       gd.num_dicsount_buys::numeric / gd.total_num_group_buys AS group_discount_share,
       CASE
           WHEN p.group_min_discount = 0 THEN NULL
           ELSE p.group_min_discount
           END                                                 AS group_minimum_discount,
       CASE
           WHEN gd.group_average_discount = 1 THEN NULL
           ELSE gd.group_average_discount
           END                                                 AS group_average_discount
FROM _pre_groups pg2
         FULL JOIN (SELECT DISTINCT cust_id, gr_id, num_dicsount_buys, total_num_group_buys, group_average_discount
                    FROM _group_discounts) AS gd
                   on gd.cust_id = pg2.customer_id AND gd.gr_id = pg2.group_id
         FULL JOIN (SELECT DISTINCT customer_id, group_id, group_min_discount FROM periods) p
                   on pg2.customer_id = p.customer_id AND pg2.group_id = p.group_id
WHERE pg2.customer_id IS NOT NULL
ORDER BY 1, 2;
