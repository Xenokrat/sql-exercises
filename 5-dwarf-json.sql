/*
Напишите запрос, который определит наиболее и наименее успешные экспедиции, учитывая:
- Соотношение выживших участников к общему числу
- Ценность найденных артефактов
- Количество обнаруженных новых мест
- Успешность встреч с существами (отношение благоприятных исходов к неблагоприятным)
- Опыт, полученный участниками (сравнение навыков до и после)

Пример:

[
  {
    "expedition_id": 2301,
    "destination": "Ancient Ruins",
    "status": "Completed",
    "survival_rate": 71.43,
    "artifacts_value": 28500,
    "discovered_sites": 3,
    "encounter_success_rate": 66.67,
    "skill_improvement": 14,
    "expedition_duration": 44,
    "overall_success_score": 0.78,
    "related_entities": {
      "member_ids": [102, 104, 107, 110, 112, 115, 118],
      "artifact_ids": [2501, 2502, 2503],
      "site_ids": [2401, 2402, 2403]
    }
  },
*/


WITH
    _BASE AS
    (
    SELECT
        e.expedition_id                                                             AS expedition_id,
        min(e.destination)                                                          AS destination,
        min(e.status)                                                               AS status,
        round(avg(em.survived::int) * 100, 2)                                       AS survival_rate,
        sum(COALESCE(ea.value, 0))                                                  AS artifacts_value,
        -- Отфильтруем только новые открытые локации
        count(DISTINCT site_id) FILTER (WHERE e.departure_date < es.discovery_date) AS discovered_sites,
        round(avg(em.outcome::int) * 100, 2)                                        AS encounter_success_rate,
        sum(level) FILTER (WHERE ds.date = e.return_date) -
        sum(level) FILTER (WHERE ds.date = e.departure_date)                        AS skill_improvement,
        EXTRACT(DAY FROM AGE(min(e.return_date), min(e.departure_date)))            AS expedition_duration
    FROM
        expedition e
    INNER JOIN
        expedition_members em USING expedition_id
    -- Предположим, есть экспедиции без артефактов, поэтому LEFT JOIN
    LEFT JOIN
        expedition_artifacts ea USING expedition_id
    INNER JOIN
        expedition_sites es USING expedition_id
    -- Предположим, есть экспедиции без существ, поэтому LEFT JOIN
    LEFT JOIN
        expedition_creatures es USING expedition_id
    INNER JOIN
        dwarf_skills ds ON em.dwarf_id = ds.dwarf_id
    GROUP BY
        e.expedition_id
    )
SELECT
    expedition_id,
    destination,
    status,
    survival_rate,
    artifacts_value,
    discovered_sites,
    encounter_success_rate,
    skill_improvement,
    expedition_duration,
    -- Не нашёл или не понял как считается `overall_success_score`,
    -- поэтому будет такая вот метрика
    ((survival_rate / 100) * 0.5
    + (encounter_success_rate / 100) * 0.5) AS overall_success_score
    JSON_OBJECT(
        "member_ids", (
            SELECT JSON_ARRAYAGG(em.dwarf_id)
            FROM expedition_members em
            WHERE b.expecdition_id, = em.expecdition_id
        ),
        "artifact_ids", (
            SELECT JSON_ARRAYAGG(ea.artifact_id)
            FROM expedition_artifacts ea
            WHERE b.expecdition_id, = ea.expecdition_id
        ),
        "site_ids", (
            SELECT JSON_ARRAYAGG(es.site_id)
            FROM expedition_sites es
            WHERE b.expecdition_id, = es.expecdition_id
        )
    ) AS related_entities
FROM
    _BASE b
