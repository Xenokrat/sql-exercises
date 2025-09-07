/*
Разработайте запрос, который анализирует эффективность каждой мастерской, учитывая:
- Производительность каждого ремесленника (соотношение созданных продуктов к затраченному времени)
- Эффективность использования ресурсов (соотношение потребляемых ресурсов к производимым товарам)
- Качество производимых товаров (средневзвешенное по ценности)
- Время простоя мастерской
- Влияние навыков ремесленников на качество товаров
{
    "workshop_id": 301,
    "workshop_name": "Royal Forge",
    "workshop_type": "Smithy",
    "num_craftsdwarves": 4,
    "total_quantity_produced": 256,
    "total_production_value": 187500,

    "daily_production_rate": 3.41,
    "value_per_material_unit": 7.82,
    "workshop_utilization_percent": 85.33,

    "material_conversion_ratio": 1.56,

    "average_craftsdwarf_skill": 7.25,

    "skill_quality_correlation": 0.83,

    "related_entities": {
      "craftsdwarf_ids": [101, 103, 108, 115],
      "product_ids": [801, 802, 803, 804, 805, 806],
      "material_ids": [201, 204, 208, 210],
      "project_ids": [701, 702, 703]
    }
},
*/


WITH
    _VALUE_PER_MATERIAL AS (
    SELECT
        wm.workshop_id,
        count(DISTINCT p.product_id) AS value_per_material_unit
    FROM
        workshop_materials wm
    LEFT JOIN
        products p ON wm.material_id = p.material_id
    GROUP BY
        wm.workshop_id,
        wm.material_id
    ),

    _MERGED_PERIOUDS AS (
    SELECT
        workshop_id,
        start_date,
        end_date,
        sum(is_new_group) OVER (PARTITION BY workshop_id ORDER BY start_date)AS group_id
        (
        SELECT
            workshop_id,
            pw.assigment_date AS start_date,
            wp.production_date AS end_date,
            -- Определяем периоды с проектами без перерывов, проверяя что проект начался или до, или в тот же
            -- день, что и предыдущий проект
            CASE
                WHEN LAG(wp.production_date) OVER (PARTITION BY workshop_id ORDER BY pw.assigment_date)
                >= pw.assigment_date - INTERVAL '1 day'
                THEN 0
                ELSE 1
            END AS is_new_group
        FROM
            workshop_products wp
        INNER JOIN
            projects pr ON w.workshop_id = pr.workshop_id
        INNER JOIN
            project_workers pw ON pr.project_id = pw.project_id
        ) t
    ),
    _CONTINUOUS_PERIODS AS (
    -- Нужно соединить периоды без перерывов в одну группу, которую мы определили выше
      SELECT
          workshop_id,
          MIN(start_date) AS period_start,
          MAX(end_date)   AS period_end
      FROM _MERGED_PERIOUDS
      GROUP BY workshop_id, group_id
    ),
    _TOTAL_PERIODS AS (
      SELECT
          workshop_id,
          MIN(period_start)              AS total_period_start,
          MAX(period_end                 AS total_period_end,
            -- Сумма периодов без "разрывов" это будет количество дней работы мастерской
          SUM(period_end - period_start) AS working_days
      FROM _CONTINUOUS_PERIODS
      GROUP BY workshop_id
    ),
    _WORKSHOP_UTILIZATION_PERCENT AS (
        SELECT
            workshop_id,
            ROUND(
                (working_days /
                (total_period_end - total_period_start) * 100) ,2) AS workshop_utilization_percent
        FROM
            _TOTAL_PERIODS
    ),

    _MATERIAL_CONVERSION_RATIO AS (
        SELECT
            workshop_id,
            avg(material_conversion_ratio_per_product) AS material_conversion_ratio
        FROM
        (
        SELECT
            wp.workshop_id,
            wp.product_id,
            (p.quality / wm.quantity) AS material_conversion_ratio_per_product
        FROM
            workshop_products wp
        JOIN
            workshop_materials wm ON wp.workshop_id = wm.workshop_id
        JOIN
            products p ON wp.product_id = p.product_id
        GROUP BY
            wp.workshop_id,
            wp.product_id
        ) t
    ),

    _CRAFT AS (
        SELECT
            t.workshop_id,
            /*
            r = cov(X,Y) / sigma(X)*sigma(Y)
            */
            (
                -- cov
                (
                    count(*) * sum(average_craftsdwarf_skill * average_quality)
                    -
                    sum(average_craftsdwarf_skill) * sum(average_quality)
                )
                /
                -- sigma(X)*sigma(Y)
                (
                    (sqrt(count(*) * sum(power(average_craftsdwarf_skill, 2)))
                        - power(sum(average_craftsdwarf_skill), 2)))
                    *
                    (sqrt(count(*) * sum(power(average_quality, 2)))
                        - power(sum(average_quality), 2)))
                )
            ) AS skill_quality_correlation,
            t.average_craftsdwarf_skill,
            s.average_quality
        FROM
        (
            SELECT
                wc.workshop_id,
                avg(ds.level) AS average_craftsdwarf_skill
            FROM
                workshop_craftsdwarves wc
            JOIN
                dwarf_skills ds ON wc.dwarf_id = ds.dwarf_id
            GROUP BY
                wc.workshop_id
        ) t
        INNER JOIN
        (
            SELECT
                wp.workshop_id,
                avg(p.quality) AS average_quality
            JOIN
                workshop_products wp ON wc.workshop_id = wp.workshop_id
            JOIN
                products p ON wp.product_id = p.product_id
        ) s
        GROUP BY
            t.workshop_id
    ),

    _BASE AS (
    SELECT
        w.workshop_id        AS workshop_id,
        w.name               AS workshop_name,
        w.type               AS workshop_type,
        count(wc.dwarf_id)   AS num_craftsdwarves,
        count(wp.product_id) AS total_quantity_produced,
        sum(p.value)         AS total_production_value,
        sum(EXTRACT(DAY FROM AGE(min(wp.production_date), min(pw.assigment_date)))) AS _total_days_to_produce,

        min(wpm.value_per_material_unit)               AS value_per_material_unit,
        min(wup.workshop_utilization_percent)          AS workshop_utilization_percent,
        min(mcr.material_conversion_ratio_per_product) AS material_conversion_ratio_per_product,

        cr.average_craftsdwarf_skill,
        cr.skill_quality_correlation

    FROM
        workshops w
    INNER JOIN
        workshop_craftsdwarves wc ON w.workshop_id = wc.workshop_id
    INNER JOIN
        workshop_products wp ON w.workshop_id = wp.workshop_id
    INNER JOIN
        products p ON wp.product_id = p.product_id
    INNER JOIN
        workshop_materials wm ON w.workshop_id = wm.workshop_id
    INNER JOIN
        projects pr ON w.workshop_id = pr.workshop_id
    INNER JOIN
        project_workers pw ON pr.project_id = pw.project_id
    INNER JOIN
        _VALUE_PER_MATERIAL vpm ON w.workshop_id = vpm.workshop_id
    INNER JOIN
        _WORKSHOP_UTILIZATION_PERCENT wup ON w.workshop_id = wup.workshop_id
    INNER JOIN
        _MATERIAL_CONVERSION_RATIO mcr ON w.workshop_id = mcr.workshop_id
    INNER JOIN
        _CRAFT cr ON w.workshop_id = cr.workshop_id
    GROUP BY
        w.workshop_id,
        w.name,
        w.type
)
SELECT
    workshop_id,
    workshop_name,
    workshop_type,
    num_craftsdwarves,
    total_quantity_produced,
    total_production_value,
    total_quantity_produced / _total_days_to_produce AS daily_production_rate,
    value_per_material_unit,
    workshop_utilization_percent,
    material_conversion_ratio_per_product,
    average_craftsdwarf_skill,
    skill_quality_correlation,
    JSON_OBJECT(
        "craftsdwarf_ids", (
            SELECT JSON_ARRAYAGG(wc.dwarf_id)
            FROM workshop_craftsdwarves wc
            WHERE b.workshop_id = wc.workshop_id
        ),
        "product_ids", (
            SELECT JSON_ARRAYAGG(wp.product_id)
            FROM workshop_products wp
            WHERE b.workshop_id = wp.workshop_id
        ),
        "material_ids", (
            SELECT JSON_ARRAYAGG(wm.material_id)
            FROM workshop_materials wm
            WHERE b.workshop_id = wm.workshop_id
        ),
        "projects_ids", (
            SELECT JSON_ARRAYAGG(wp.project_id)
            FROM workshop_projects wp
            WHERE b.workshop_id = wp.workshop_id
        )
    ) AS related_entities
FROM
    _BASE b
