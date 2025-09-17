WITH
    _CIVIL_DATA AS (
        SELECT
            JSON_ARRAY(
                SELECT
                    c.fortress_id,
                    c.civilization_type          AS civilization_type,
                    count(DISTINCT c.caravan_id) AS total_caravans,
                    sum(tt.value)                AS total_trade_value,
                    sum(tt.balance_direction)    AS trade_balance,
                    case (sum(case relationship_change when > 0 then 1 else -1 end)) > 0
                        then 'Favorable'
                        else 'Unfavorable'
                        end
                    AS trade_relationship,
                    CORR(relationship_change, value) AS diplomatic_correlation,
                    JSON_ARRAYAGG(c.caravan_id)  AS caravan_ids
                FROM
                    caravans c
                LEFT JOIN
                    trade_transactions tt ON c.caravan_id = tt.caravan_id
                GROUP BY
                    c.fortress_id,
                    c.civilization_type
            ) AS civilization_trade_data
    ),
    _RESOURCE_DEPENDENCY AS (
        SELECT
            JSON_ARRAY(
                (
                SELECT
                    fortress_id,
                    materials_transation.material_type    AS material_type,
                    material_dependency.material_required AS dependency_score,
                    materials_transation.total_imported   AS total_importet,
                    materials_transation.import_diversity AS import_diversity,
                    JSON_ARRAY(material_dependency)       AS resource_ids
                FROM (
                    SELECT
                        fortress_id,
                        material_id,
                        sum(pm.quantity_required - pm.quantity_available) AS material_required
                    FROM
                        workshop_materials wm
                    JOIN
                        workshops w ON wm.workshop_id = w.workshop_id
                    JOIN
                        project_materials pm ON wm.material_id = pm.material_id
                    WHERE
                        is_input = true
                    GROUP BY
                        fortress_id,
                        material_id
                ) AS material_dependency
                JOIN
                (
                    SELECT
                        fortress_id,
                        UNNEST(caravan_items)             AS material_id,
                        min(cg.material_type)             AS material_type,
                        count(DISTINCT civilization_type) AS import_diversity,
                        sum(tt.value)                     AS total_imported
                    FROM
                        caravans c
                    JOIN
                        trade_transactions tt ON c.caravan_id = tt.caravan_id
                    JOIN
                        caravan_goods cg ON c.caravan_id = cg.caravan_id
                    GROUP BY
                        fortress_id,
                        material_id
                ) AS materials_transation ON  material_dependency.fortress_id = materials_transation.fortress_id
                                          AND material_dependency.material_id = materials_transation.material_id
                )
            ) AS resource_dependency
    ),
    _EXPORT_EFFECTIVENESS AS (
        SELECT
            JSON_ARRAY(
                SELECT
                    fortress_workshops.fortress_id   AS fortress_id,
                    fortress_workshops.workshop_type AS workshop_type,
                    fortress_workshops.product_type  AS product_type,
                    avg(fortress_workshops.produced_quantity / fortress_export.export_quantity) AS export_ratio
                    avg(fortress_export.export_value - fortress_workshops.product_value) AS avg_markup,
                    JSON_ARRAY(fortress_workshops.workshop_id) AS workshop_ids
                FROM
                (
                    SELECT
                        w.fortress_id,
                        w.workshop_id,
                        w.type AS workshop_type,
                        wp.product_id,
                        p.type AS product_type,
                        avg(p.value) AS product_value,
                        sum(wp.quantity) AS produced_quantity
                    FROM
                        workshops w
                    LEFT JOIN
                        workshop_products wp ON w.workshop_id = wp.workshop_id
                    LEFT JOIN
                        products p ON wp.product_id = p.product_id
                    GROUP BY
                        w.fortress_id,
                        w.workshop_id,
                        w.type AS workshop_type,
                        wp.product_id
                ) fortress_workshops
                JOIN
                (
                    SELECT
                        c.fortress_id,
                        c.caravan_id,
                        UNNEST(tt.fortress_items) AS product_id,
                        sum(cg.value) AS export_value,
                        count(product_id) AS export_quantity
                    FROM
                        caravans c
                    LEFT JOIN
                        caravan_goods cg ON c.caravan_id = cg.caravan_id AND
                    LEFT JOIN
                        trade_transactions tt ON c.caravan_id = tt.caravan_id
                    GROUP BY
                        fortress_id,
                        product_id
                ) fortress_export ON fortress_workshops.fortress_id = fortress_export.fortress_id
                                 AND fortress_workshops.product_id = fortress_export.product_id
            GROUP BY
                fortress_id,
                workshop_type,
                product_type
            ) AS export_effectiveness
    ),
    _TRADE_GROWTH AS (
        SELECT
            JSON_ARRAY(
                SELECT
                    EXTRACT(YEAR FROM c.departure_date)    AS year,
                    EXTRACT(QUARTER FROM c.departure_date) AS quarter,
                    sum(tt.value)                          AS quarterly_value,
                    sum(tt.balance_direction)              AS quarterly_balance,
                    count(DISTINCT c.civilization_type)    AS trade_diversity
                FROM
                    caravans c
                LEFT JOIN
                    trade_transactions tt ON c.caravan_id = tt.caravan_id
                GROUP BY
                    year,
                    quarter
            ) AS trade_growth
    )
SELECT
    count(DISTINCT c.civilization_type)    AS total_trading_partners
    sum(tt.value)                          AS all_time_trade_value,
    sum(tt.balance_direction)              AS all_time_trade_balance,
    JSON_OBJECT(
        "civilization_data", (
            SELECT
                civilization_trade_data
            FROM
                _CIVIL_DATA cd
            WHERE
                c.fortress_id = cd.fortress_id
    )),
    JSON_OBJECT(
        "critical_import_dependencies", (
            SELECT
                resource_dependency
            FROM
                _RESOURCE_DEPENDENCY rd
            WHERE
                c.fortress_id = rd.fortress_id
    )),
    JSON_OBJECT(
        "export_effectiveness", (
            SELECT
                export_effectiveness
            FROM
                _EXPORT_EFFECTIVENESS ef
            WHERE
                c.fortress_id = ef.fortress_id
    )),
    JSON_OBJECT(
        "trade_timeline", (
            SELECT
                trade_growth
            FROM
                _TRADE_GROWTH tg
            WHERE
                c.fortress_id = tg.fortress_id
    )),
FROM
    caravans c
LEFT JOIN
    trade_transactions tt ON c.caravan_id = tt.caravan_id
GROUP BY
    fortress_id

