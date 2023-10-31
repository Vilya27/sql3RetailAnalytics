DROP VIEW IF EXISTS _min_discounts CASCADE;
DROP MATERIALIZED VIEW IF EXISTS "periods" CASCADE;

CREATE VIEW _min_discounts AS
SELECT DISTINCT customer_id                                                                        AS cust_id,
                pg.group_id                                                                        AS gr_id,
                MIN(sku_discount::numeric / sku_summ)
                OVER (PARTITION BY pg.group_id, customer_id)                                       AS min_dicsount_percent
FROM _total_data
         FULL JOIN product_grid pg ON _total_data.sku_id = pg.sku_id
         FULL JOIN sku_group sg on sg.group_id = pg.group_id
WHERE sku_discount::numeric / sku_summ != 0
ORDER BY 1, 2;

CREATE MATERIALIZED VIEW periods AS
SELECT DISTINCT customer_id,
                group_id,
                MIN(transaction_datetime) OVER (PARTITION BY customer_id, group_id) AS First_Group_Purchase_Date,
                MAX(transaction_datetime) OVER (PARTITION BY customer_id, group_id) AS Last_Group_Purchase_Date,
                COUNT(transaction_id) OVER (PARTITION BY customer_id, group_id)     AS Group_Purchase,
                (EXTRACT(EPOCH FROM (MAX(transaction_datetime) OVER (PARTITION BY customer_id, group_id) -
                                     MIN(transaction_datetime) OVER (PARTITION BY customer_id, group_id))) / 60 / 60 /
                 24 + 1)::numeric /
                COUNT(transaction_id) OVER (PARTITION BY customer_id, group_id)     AS Group_Frequency,
                COALESCE(min_dicsount_percent, 0)                                   AS Group_Min_Discount
FROM purchase_history ph
         FULL JOIN _min_discounts md ON ph.group_id = md.gr_id AND ph.customer_id = md.cust_id
ORDER BY 1, 2;


