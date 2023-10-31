DROP FUNCTION IF EXISTS fnc_personal_offers_cross_selling(int, numeric, numeric, numeric, numeric);
DROP FUNCTION IF EXISTS fnc_round_in_increments_of_5(int, numeric, numeric, numeric, numeric);

CREATE OR REPLACE FUNCTION fnc_round_in_increments_of_5(group_minimum_discount numeric)
    RETURNS numeric
    LANGUAGE plpgsql
AS
$$
DECLARE
    res numeric := 0;
BEGIN
    FOR i IN 5..100 BY 5
        LOOP
            CASE
                WHEN (i >= group_minimum_discount)
                    THEN res := i;
                         exit;
                ELSE res := 0;
                END case;
        END LOOP;
    RETURN res;
END;
$$;

CREATE OR REPLACE FUNCTION fnc_personal_offers_cross_selling(num_of_groups int, max_churn_rate numeric,
                                                             max_stability_index numeric, max_sku_stake numeric,
                                                             max_margin_stake numeric)

    RETURNS TABLE
            (
                customer_id        integer,
                sku_name           varchar,
                offer_discount_depth numeric
            )
    LANGUAGE plpgsql
AS
$$

BEGIN
    RETURN QUERY
        WITH group_selection AS (SELECT f.group_id,
                                        f.group_minimum_discount,
                                        f.num,
                                        f.customer_id
                                 FROM (SELECT groups.customer_id,
                                              groups.group_id,
                                              groups.group_minimum_discount,
                                              row_number() OVER (PARTITION BY groups.customer_id) AS num
                                       FROM groups
                                       WHERE groups.group_churn_rate <= max_churn_rate::numeric
                                         AND groups.group_stability_index < max_stability_index::numeric) f
                                 WHERE f.group_minimum_discount is not null
                                   AND f.num <= num_of_groups
                                 ORDER BY f.customer_id),

             customer_primary_shop AS (SELECT customers.customer_id,
                                              customers.customer_primary_store
                                       FROM customers),

             groups_and_stores AS (SELECT group_selection.customer_id,
                                          group_selection.group_id,
                                          group_selection.group_minimum_discount,
                                          customer_primary_shop.customer_primary_store
                                   FROM group_selection
                                            JOIN customer_primary_shop USING (customer_id)),

             margin AS (SELECT stores.sku_id,
                               stores.transaction_store_id,
                               stores.sku_purchase_price,
                               stores.sku_retail_price,
                               product_grid.sku_name,
                               product_grid.group_id,
                               stores.sku_retail_price - stores.sku_purchase_price AS margin
                        FROM stores
                                 JOIN product_grid USING (sku_id)),

             max_margin AS (SELECT margin.group_id,
                                   margin.transaction_store_id,
                                   max(margin.margin) AS max
                            FROM margin
                            GROUP BY margin.group_id, margin.transaction_store_id),

             margin_for_customer AS (SELECT g.customer_id,
                                            g.group_id,
                                            g.group_minimum_discount,
                                            g.customer_primary_store,
                                            n.max
                                     FROM groups_and_stores g
                                              JOIN max_margin n ON g.customer_primary_store = n.transaction_store_id
                                     WHERE g.group_id = n.group_id),

             margin_for_customer_with_sku_id AS (SELECT t.customer_id,
                                                        t.group_id,
                                                        t.group_minimum_discount,
                                                        t.customer_primary_store,
                                                        t.max,
                                                        n.sku_id,
                                                        n.sku_name,
                                                        n.sku_retail_price,
                                                        n.sku_purchase_price
                                                 FROM margin_for_customer t
                                                          JOIN margin n ON t.max = n.margin
                                                 ORDER BY t.customer_id),

             sku_percentage AS (SELECT c.customer_id,
                                       checks.sku_id,
                                       count(checks.sku_id) AS count
                                FROM checks
                                         JOIN transactions t2 on t2.transaction_id = checks.transaction_id
                                         JOIN cards c on c.customer_card_id = t2.customer_card_id
                                GROUP BY c.customer_id, checks.sku_id),

             group_percentage AS (SELECT product_grid.group_id,
                                         count(checks.sku_id) AS count_group
                                  FROM checks
                                           JOIN product_grid USING (sku_id)
                                  GROUP BY product_grid.group_id),

             sku_percentage_plus_group AS (SELECT sku_percentage.customer_id,
                                                  sku_percentage.sku_id,
                                                  sku_percentage.count AS count_sku,
                                                  product_grid.sku_name,
                                                  product_grid.group_id
                                           FROM sku_percentage
                                                    JOIN product_grid USING (sku_id)),

             all_counts AS (SELECT sku_percentage_plus_group.customer_id,
                                   sku_percentage_plus_group.group_id,
                                   sku_percentage_plus_group.sku_id,
                                   sku_percentage_plus_group.count_sku,
                                   sku_percentage_plus_group.sku_name,
                                   group_percentage.count_group
                            FROM sku_percentage_plus_group
                                     JOIN group_percentage USING (group_id)),

             percentages AS (SELECT all_counts.customer_id,
                                    all_counts.group_id,
                                    all_counts.sku_id,
                                    all_counts.count_sku,
                                    all_counts.sku_name,
                                    all_counts.count_group,
                                    all_counts.count_sku::numeric / all_counts.count_group::numeric *
                                    100::numeric AS percentage
                             FROM all_counts),

             sku_with_percentage AS (SELECT percentages.customer_id,
                                            percentages.group_id,
                                            percentages.sku_id,
                                            percentages.count_sku,
                                            percentages.sku_name,
                                            percentages.count_group,
                                            percentages.percentage
                                     FROM percentages
                                     WHERE percentages.percentage <= max_sku_stake::numeric),

             sku_for_discount AS (SELECT t.customer_id,
                                         t.group_id,
                                         t.group_minimum_discount,
                                         t.customer_primary_store,
                                         t.max AS margin,
                                         t.sku_id,
                                         t.sku_name,
                                         t.sku_retail_price,
                                         t.sku_purchase_price
                                  FROM margin_for_customer_with_sku_id t
                                           JOIN sku_with_percentage d USING (customer_id, sku_id)
                                  WHERE t.group_id = d.group_id),


             discount_depth AS (SELECT sku_for_discount.customer_id,
                                       sku_for_discount.sku_name,
                                       sku_for_discount.group_id,
                                       sku_for_discount.group_minimum_discount,
                                       fnc_round_in_increments_of_5(sku_for_discount.group_minimum_discount * 100) as rounded_discount,
                                       sku_for_discount.sku_retail_price,
                                       sku_for_discount.sku_purchase_price,
                                       sku_for_discount.margin,
                                       sku_for_discount.margin * max_margin_stake::numeric /
                                       sku_for_discount.sku_retail_price                                           AS discount_depth_value
                                FROM sku_for_discount),

             answer AS (SELECT discount_depth.customer_id,
                               discount_depth.group_id,
                               discount_depth.sku_name,
                               discount_depth.group_minimum_discount,
                               discount_depth.rounded_discount,
                               discount_depth.sku_retail_price,
                               discount_depth.sku_purchase_price,
                               discount_depth.margin,
                               discount_depth.discount_depth_value,
                               CASE
                                   WHEN discount_depth.discount_depth_value >= discount_depth.rounded_discount THEN true
                                   ELSE false
                                   END AS truefalse
                        FROM discount_depth)

        SELECT answer.customer_id,
               answer.sku_name,
               fnc_round_in_increments_of_5(answer.rounded_discount) AS offer_discount_depth
        FROM answer
        WHERE truefalse = true
        ORDER BY customer_id, group_id;
END;
$$;

--SELECT * FROM fnc_personal_offers_cross_selling(2, 0.8, 1, 12, 12);
SELECT *
FROM fnc_personal_offers_cross_selling(5, 3, 0.5, 100, 30);


