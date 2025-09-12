/*
 Создайте запрос, оценивающий эффективность военных отрядов на основе:
- Результатов всех сражений (победы/поражения/потери)
- Соотношения побед к общему числу сражений
- Навыков членов отряда и их прогресса
- Качества экипировки
- Истории тренировок и их влияния на результаты
- Выживаемости членов отряда в долгосрочной перспективе

Возможный вариант выдачи:

[
  {
    "squad_id": 401,
    "squad_name": "The Axe Lords",
    "formation_type": "Melee",
    "leader_name": "Urist McAxelord",
    "total_battles": 28,
    "victories": 22,
    "victory_percentage": 78.57,
    "casualty_rate": 24.32,
    "casualty_exchange_ratio": 3.75,
    "current_members": 8,
    "total_members_ever": 12,
    "retention_rate": 66.67,
    "avg_equipment_quality": 4.28,
    "total_training_sessions": 156,
    "avg_training_effectiveness": 0.82,
    "training_battle_correlation": 0.76,
    "avg_combat_skill_improvement": 3.85,
    "overall_effectiveness_score": 0.815,
    "related_entities": {
      "member_ids": [102, 104, 105, 107, 110, 115, 118, 122],
      "equipment_ids": [5001, 5002, 5003, 5004, 5005, 5006, 5007, 5008, 5009],
      "battle_report_ids": [1101, 1102, 1103, 1104, 1105, 1106, 1107, 1108],
      "training_ids": [901, 902, 903, 904, 905, 906]
    }
  },
]
*/

WITH
    _MEMBERS AS (
        SELECT
            ms.squad_id,
            count(DISTINCT sm.dwarf_id) FILTER (WHERE sm.exit_date IS NULL)  AS current_members,
            count(DISTINCT sm.dwarf_id)                                      AS total_members_ever
        FROM
            military_squads ms
        LEFT JOIN
            squad_members sm ON ms.squad_id = sm.squad_id
        GROUP BY
            ms.squad_id
    ),
    _EQUIPMENT AS (
        SELECT
            ms.squad_id,
            avg(quality) AS avg_equipment_quality,
        FROM
            military_squads ms
        LEFT JOIN
            squad_equipment se ON ms.squad_id = se.squad_id
        LEFT JOIN
            equipment e ON se.equipment_id = e.equipment_id
        GROUP BY
            ms.squad_id
    ),
    _TRAINING AS (
        SELECT
            ms.squad_id
            count(st.schedule_id) AS total_training_sessions,
            avg(st.effectiveness) AS avg_training_effectiveness,
        FROM
            military_squads ms
        LEFT JOIN
            squad_training st ON ms.squad_id = st.squad_id
        GROUP BY
            ms.squad_id
    ),
    _SKILL_IMPROVEMENT AS (
        SELECT
            squad_id,
            avg(current_level - previous_level) AS avg_skill_improvment
        FROM (
            SELECT
                squad_id,
                dwarf_id,
                sb.date,
                db.report_id AS report_id,
                LAG(ds.level) OVER (PARTITION BY (sm.squad_id, ds.dwarf_id, sb.report_id)
                                    ROWS UNBOUND PRECEEDING AND CURRENT ROW
                                    ORDER BY sb.date) AS previous_level
                ds.level AS current_level
            FROM
                squad_members sm
            LEFT JOIN
                dwarf_skills ds ON sm.dwarf_id = ds.dwarf_id
            LEFT JOIN
                squad_battles sb ON sm.squad_id = sb.squad_id
        ) t
        GROUP BY
            squad_id
    ),
    _BASE AS (
        SELECT
            squad_id                                                           AS squad_id,
            name                                                               AS squad_name,
            formation_type                                                     AS formation_type,
            NULLIF(d.name, "No Name")                                          AS leader_name,
            count(DISTINCT sb.report_id)                                       AS total_battles,
            count(DISTINCT sb.report_id) FILTER (WHERE sb.outcome = 'Victory') AS victories,
            sum(sb.casualties)                                                 AS casualties,
            sum(sb.enemy_casualties)                                           AS enemy_casualties,
        FROM
            military_squads ms
        LEFT JOIN
            dwarves d ON ms.leader_id = d.dwarf_id
        LEFT JOIN
            squad_battles sb ON ms.squad_id = sb.squad_id
        GROUP BY
            squad_id,
            name,
            formation_type
)
SELECT
    b.squad_id,
    b.squad_name,
    b.formation_type,
    b.leader_name,
    b.total_battles,
    b.victories,
    ROUND(b.victories / b.total_battles, 2)       AS victory_percentage,
    ROUND(b.casualties / b.total_battles, 2)      AS casualty_rate,
    ROUND(b.enemy_casualties / b.casualties, 2)   AS casualty_exchange_ratio,
    m.current_members,
    m.total_members_ever,
    ROUND(m.current_members / m.total_members_ever, 2)   AS retention_rate,
    e.avg_equipment_quality,
    t.total_training_sessions,
    t.avg_training_effectiveness,
    CORR(t.avg_training_effectiveness, ROUND(b.victories / b.total_battles, 2)) AS training_battle_correlation,
    si.avg_combat_skill_improvement,
    ROUND((victory_percentage + casualty_exchange_ratio + retention_rate + avg_training_effectiveness) / 4, 2)
        AS overall_effectiveness_score,
    JSON_OBJECT(
        "member_ids", (
            SELECT JSON_ARRAYAGG(sm.dwarf_id)
            FROM squad_members sm
            WHERE b.squad_id = sm.squad_id
        ),
        "equipment_ids", (
            SELECT JSON_ARRAYAGG(se.equipment_id)
            FROM squad_equipment se
            WHERE b.squad_id = se.squad_id
        ),
        "battle_report_ids", (
            SELECT JSON_ARRAYAGG(sb.report_id)
            FROM squad_battles sb
            WHERE b.squad_id = sb.squad_id
        ),
        "training_ids", (
            SELECT JSON_ARRAYAGG(st.schedule_id)
            FROM squad_training st
            WHERE b.squad_id = st.squad_id
        )
    ) AS related_entities
FROM
    _BASE b
JOIN
    _MEMBERS m ON b.squad_id = m.squad_id
JOIN
    _EQUIPMENT e ON b.squad_id = e.squad_id
JOIN
    _TRANING t ON b.squad_id = t.squad_id
JOIN
    _SKILL_IMPROVMENT si ON b.squad_id = si.squad_id
