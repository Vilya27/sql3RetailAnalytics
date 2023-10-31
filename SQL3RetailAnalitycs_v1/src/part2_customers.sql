DROP VIEW IF EXISTS _total_data, _pre_customers_view, _pre_pre_customers_view, _pre_favourite_shop, _favourite_shop, _pre_favourite_shop_by_percent_visits CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "customers" CASCADE;

CREATE VIEW _total_data AS
WITH data AS (SELECT *,
                     average_Check                                             AS Customer_Average_Check,
                     MIN(transaction_datetime) OVER (PARTITION BY customer_id) AS Earliest_visit,
                     MAX(transaction_datetime) OVER (PARTITION BY customer_id) AS Latest_visit,
                     cust_num_visit                                            AS Num_visit,
                     SUM(Store_visit_count_2)                                  AS Store_visit_count,
                     CASE
                         WHEN (COUNT(transaction_datetime) OVER (PARTITION BY customer_id)) = 0 THEN 0
                         ELSE
                                 Store_visit_count_2::numeric /
                                 (SUM(Store_visit_count_2) OVER (PARTITION BY customer_id))::numeric
                         END                                                   AS Percent_visits_for_store
              FROM personal_information p
                       FULL JOIN (SELECT customer_id AS cust_id, customer_card_id AS cust_card_id FROM cards) AS c
                                 ON p.customer_id = c.cust_id
                       FULL JOIN transactions t ON c.cust_card_id = t.customer_card_id
                       FULL JOIN (SELECT transaction_id AS transact_id,
                                         sku_id,
                                         sku_amount,
                                         sku_summ,
                                         sku_summ_paid,
                                         sku_discount
                                  FROM checks) AS c2 ON t.transaction_id = c2.transact_id
                       FULL JOIN (SELECT DISTINCT customer_id                                           AS cust_id_for_average_check,
                                                  AVG(transaction_summ) OVER (PARTITION BY customer_id) AS average_Check
                                  FROM cards c
                                           FULL JOIN transactions t ON c.customer_card_id = t.customer_card_id) AS avg_check
                                 ON p.customer_id = avg_check.cust_id_for_average_check
                       FULL JOIN (SELECT DISTINCT customer_id                                                 AS cust_id_num_visit,
                                                  COUNT(transaction_datetime) OVER (PARTITION BY customer_id) AS cust_num_visit
                                  FROM cards c
                                           FULL JOIN transactions t ON c.customer_card_id = t.customer_card_id) AS n_visits
                                 ON p.customer_id = n_visits.cust_id_num_visit
                       FULL JOIN (SELECT DISTINCT customer_id                                           AS cust_id_num_visit_2,
                                                  transaction_store_id                                  AS tr_store_id,
                                                  COUNT(transaction_store_id)
                                                  OVER (PARTITION BY customer_id, transaction_store_id) AS Store_visit_count_2
                                  FROM cards c
                                           FULL JOIN transactions t ON c.customer_card_id = t.customer_card_id) AS n_visits_2
                                 ON p.customer_id = n_visits_2.cust_id_num_visit_2 AND
                                    t.transaction_store_id = n_visits_2.tr_store_id
              GROUP BY customer_id, cust_id, cust_card_id, transaction_id, transact_id, sku_id, sku_amount, sku_summ,
                       sku_summ_paid, sku_discount, cust_id_for_average_check, average_Check, cust_id_num_visit,
                       cust_num_visit, cust_id_num_visit_2, tr_store_id, Store_visit_count_2)
SELECT *
FROM data;

CREATE VIEW _pre_customers_view AS
SELECT customer_id,
       Customer_Average_Check,
       CASE
           WHEN Customer_Average_Check IS NULL THEN NULL
           WHEN percent_rank()
                OVER (PARTITION BY Customer_Average_Check IS NOT NULL ORDER BY Customer_Average_Check DESC) <= 0.1
               THEN 'High'
           WHEN percent_rank()
                OVER (PARTITION BY Customer_Average_Check IS NOT NULL ORDER BY Customer_Average_Check DESC) <= 0.35
               THEN 'Medium'
           ELSE 'Low'
           END                                                                          AS Customer_Average_Check_Segment,
       EXTRACT(EPOCH FROM (Latest_visit - Earliest_visit)) / 60 / 60 / 24 / Num_visit   AS Customer_Frequency,
       EXTRACT(EPOCH FROM ((SELECT MAX(analysis_formation) FROM date_of_analysis) - Latest_visit)) / 60 / 60 /
       24                                                                               AS Customer_Inactive_Period,
       (EXTRACT(EPOCH FROM ((SELECT MAX(analysis_formation) FROM date_of_analysis) - Latest_visit)) / 60 / 60 / 24) /
       (EXTRACT(EPOCH FROM (Latest_visit - Earliest_visit)) / 60 / 60 / 24 / Num_visit) AS Customer_Churn_Rate

FROM _total_data
GROUP BY customer_id, Customer_Average_Check, Latest_visit, Earliest_visit, Num_visit
ORDER BY 1
;

CREATE VIEW _pre_pre_customers_view AS
SELECT customer_id,
       Customer_Average_Check,
       Customer_Average_Check_Segment,
       Customer_Frequency,
       CASE
           WHEN Customer_Frequency IS NULL THEN NULL
           WHEN percent_rank()
                OVER (PARTITION BY Customer_Frequency IS NOT NULL ORDER BY Customer_Frequency) <= 0.1
               THEN 'Often'
           WHEN percent_rank()
                OVER (PARTITION BY Customer_Frequency IS NOT NULL ORDER BY Customer_Frequency) <= 0.35
               THEN 'Occasionaly'
           ELSE 'Rarely'
           END AS Customer_Frequency_Segment,
       Customer_Inactive_Period,
       Customer_Churn_Rate,

       CASE
           WHEN Customer_Churn_Rate IS NULL THEN NULL
           WHEN Customer_Churn_Rate BETWEEN 0 AND 2 THEN 'Low'
           WHEN Customer_Churn_Rate BETWEEN 2 AND 5 THEN 'Medium'
           ELSE 'High'
           END AS Customer_Churn_Segment
FROM _pre_customers_view
GROUP BY customer_id, Customer_Average_Check, Customer_Average_Check_Segment, Customer_Frequency,
         Customer_Inactive_Period, Customer_Churn_Rate
ORDER BY 1
;

CREATE VIEW _pre_favourite_shop AS
WITH shop_visits_data AS (SELECT customer_id, transaction_datetime, transaction_store_id, transaction_id
                          FROM (SELECT t_d.*,
                                       ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY transaction_datetime DESC) i
                                FROM (SELECT DISTINCT customer_id,
                                                      transaction_datetime,
                                                      transaction_store_id,
                                                      transaction_id
                                      FROM _total_data) t_d) t
                          WHERE i <= 3)
SELECT customer_id,
       transaction_datetime,
       transaction_store_id,
       MIN(transaction_store_id) OVER (PARTITION BY customer_id) AS min_num_of_favourite_store,
       SUM(transaction_store_id) OVER (PARTITION BY customer_id) AS check_sum_favourite_store_1
FROM shop_visits_data
GROUP BY customer_id, transaction_datetime, transaction_store_id;

CREATE VIEW _favourite_shop AS
SELECT *,
       CASE
           WHEN SUM(check_sum_favourite_store_1) OVER (PARTITION BY customer_id) =
                SUM(check_sum_favourite_store_2) OVER (PARTITION BY customer_id) THEN 'Yes'
           ELSE 'No'
           END AS Is_Last_Three_Visits_In_Same_Shop
FROM (SELECT customer_id,
             transaction_datetime,
             transaction_store_id,
             min_num_of_favourite_store,
             check_sum_favourite_store_1,
             SUM(min_num_of_favourite_store) OVER (PARTITION BY customer_id) AS check_sum_favourite_store_2
      FROM _pre_favourite_shop) AS X;

CREATE VIEW _pre_favourite_shop_by_percent_visits AS
WITH shop_visits_data_2 AS (SELECT customer_id, Percent_visits_for_store, transaction_datetime, transaction_store_id
                            FROM (SELECT _total_data.*,
                                         ROW_NUMBER()
                                         OVER (PARTITION BY customer_id ORDER BY Percent_visits_for_store DESC, transaction_datetime DESC) i
                                  FROM _total_data) t
                            WHERE i <= 1)
SELECT customer_id,
       Percent_visits_for_store,
       transaction_datetime,
       transaction_store_id
FROM shop_visits_data_2
GROUP BY customer_id, Percent_visits_for_store, transaction_datetime, transaction_store_id;

CREATE CREATE MATERIALIZED VIEW customers AS
SELECT customer_id,
       Customer_Average_Check,
       Customer_Average_Check_Segment,
       Customer_Frequency,
       Customer_Frequency_Segment,
       Customer_Inactive_Period,
       Customer_Churn_Rate,
       Customer_Churn_Segment,
       CASE
           WHEN Customer_Average_Check_Segment IS NULL THEN NULL
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'Low' THEN 1
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'Medium' THEN 2
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'High' THEN 3
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'Low' THEN 4
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'Medium' THEN 5
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'High' THEN 6
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'Low' THEN 7
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'Medium' THEN 8
           WHEN Customer_Average_Check_Segment = 'Low' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'High' THEN 9
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'Low' THEN 10
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'Medium' THEN 11
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'High' THEN 12
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'Low' THEN 13
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'Medium' THEN 14
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'High' THEN 15
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'Low' THEN 16
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'Medium' THEN 17
           WHEN Customer_Average_Check_Segment = 'Medium' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'High' THEN 18
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'Low' THEN 19
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'Medium' THEN 20
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Rarely' AND Customer_Churn_Segment = 'High' THEN 21
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'Low' THEN 22
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'Medium' THEN 23
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Occasionaly' AND Customer_Churn_Segment = 'High' THEN 24
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'Low' THEN 25
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'Medium' THEN 26
           WHEN Customer_Average_Check_Segment = 'High' AND Customer_Frequency_Segment = 'Often' AND Customer_Churn_Segment = 'High' THEN 27
           END                                                                         AS Customer_Segment,
       CASE
           WHEN Is_Last_Three_Visits_In_Same_Shop = 'Yes' THEN transaction_store_id
           ELSE tran_store_id_by_percent_visits
           END AS Customer_Primary_Store
FROM _pre_pre_customers_view
         FULL JOIN (SELECT customer_id AS cust_id, transaction_store_id, Is_Last_Three_Visits_In_Same_Shop
                    FROM _favourite_shop
                    WHERE Is_Last_Three_Visits_In_Same_Shop = 'Yes') AS fav_shop
                   ON _pre_pre_customers_view.customer_id = fav_shop.cust_id
         FULL JOIN (SELECT customer_id AS cust_id_2, transaction_store_id as tran_store_id_by_percent_visits
                    FROM _pre_favourite_shop_by_percent_visits) AS fav_shop_2
                   ON _pre_pre_customers_view.customer_id = fav_shop_2.cust_id_2
GROUP BY customer_id, Customer_Average_Check, Customer_Average_Check_Segment, Customer_Frequency,
         Customer_Frequency_Segment, Customer_Inactive_Period, Customer_Churn_Rate, Customer_Churn_Segment,
         Is_Last_Three_Visits_In_Same_Shop, transaction_store_id, tran_store_id_by_percent_visits
ORDER BY 1
;
