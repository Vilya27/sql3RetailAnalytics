DROP MATERIALIZED VIEW IF EXISTS "purchase_history" CASCADE;

CREATE MATERIALIZED VIEW purchase_history AS
    SELECT p.customer_id, t.transaction_id, t.transaction_datetime, pg.group_id, 
        SUM(ch.sku_amount*s.sku_purchase_price) AS group_cost, 
        SUM(ch.sku_summ) AS group_summ, 
        SUM(ch.sku_summ_paid) AS group_summ_paid
    FROM transactions t
    full JOIN cards c ON t.customer_card_id = c.customer_card_id
    full JOIN personal_information p ON c.customer_id = p.customer_id
    full JOIN checks ch ON ch.transaction_id = t.transaction_id
    full JOIN product_grid pg ON pg.sku_id = ch.sku_id
    full JOIN stores s ON s.sku_id = ch.sku_id AND s.transaction_store_id = t.transaction_store_id
    GROUP BY p.customer_id, t.transaction_id, pg.group_id
    ORDER BY p.customer_id, t.transaction_id, pg.group_id;


-- SELECT * FROM purchase_history;
    
