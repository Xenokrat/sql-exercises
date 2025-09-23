SELECT JSON_OBJECT(
    'total_recorded_attacks', (
        SELECT COUNT(*)
        FROM creature_attacks ca
        JOIN creature_sightings cs ON ca.creature_id = cs.creature_id
        WHERE cs.location = f.location
    ),

    'unique_attackers', (
        SELECT COUNT(DISTINCT ca.creature_id)
        FROM creature_attacks ca
        JOIN creature_sightings cs ON ca.creature_id = cs.creature_id
        WHERE cs.location = f.location
    ),

    'overall_defense_success_rate', (
        SELECT ROUND(
            (SUM(CASE WHEN ca.outcome = 'Victory' THEN 1 ELSE 0 END) * 100.0 /
            NULLIF(COUNT(*), 0)), 2
        )
        FROM creature_attacks ca
        JOIN creature_sightings cs ON ca.creature_id = cs.creature_id
        WHERE cs.location = f.location
    ),

    'security_analysis', JSON_OBJECT(
        'threat_assessment', (
            SELECT JSON_OBJECT(
                'current_threat_level', CASE
                    WHEN MAX(c.threat_level) >= 4 THEN 'High'
                    WHEN MAX(c.threat_level) >= 2 THEN 'Moderate'
                    ELSE 'Low'
                END,
                'active_threats', JSON_ARRAYAGG(
                    JSON_OBJECT(
                        'creature_type', c.type,
                        'threat_level', c.threat_level,
                        'last_sighting_date', (
                            SELECT MAX(cs2.date)
                            FROM creature_sightings cs2
                            WHERE cs2.creature_id = c.creature_id
                        ),
                        'territory_proximity', (
                            SELECT MIN(ct.distance_to_fortress)
                            FROM creature_territories ct
                            WHERE ct.creature_id = c.creature_id
                        ),
                        'estimated_numbers', c.estimated_population,
                        'creature_ids', JSON_ARRAY(c.creature_id)
                    )
                )
            )
            FROM creatures c
            WHERE c.active = 1
            AND c.creature_id IN (
                SELECT DISTINCT cs.creature_id
                FROM creature_sightings cs
                WHERE cs.location = f.location
            )
        ),

        'vulnerability_analysis', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'zone_id',   l.zone_id,
                    'zone_name', l.name,
                    -- Формула произвольная
                    'vulnerability_score', ROUND(
                        (l.choke_points * 0.3 +
                         (10 - l.fortification_level) * 0.4 +
                         (100 - l.wall_integrity) * 0.3) / 10, 2
                    ),
                    'historical_breaches', (
                        SELECT COUNT(*)
                        FROM creature_attacks ca
                        JOIN creature_sightings cs ON ca.creature_id = cs.creature_id
                        WHERE cs.location = l.name
                        AND ca.outcome = 'Defeat'
                    ),
                    'fortification_level', l.fortification_level,
                    'military_response_time', (
                        SELECT AVG(sco.response_time)
                        FROM squad_coverage sco
                        JOIN military_squads ms ON sco.squad_id = ms.squad_id
                        WHERE sco.zone_id = l.zone_id
                        AND ms.fortress_id = f.fortress_id
                    ),
                    'defense_coverage', JSON_OBJECT(
                        'structure_ids', (
                            SELECT JSON_ARRAYAGG(ds.structure_id)
                            FROM defense_structures ds
                            WHERE ds.location_id = l.location_id
                        ),
                        'squad_ids', (
                            SELECT JSON_ARRAYAGG(ms.squad_id)
                            FROM military_squads ms
                            JOIN squad_coverage sc ON ms.squad_id = sc.squad_id
                            WHERE sc.zone_id = l.zone_id
                            AND ms.fortress_id = f.fortress_id
                        )
                    )
                )
            )
            FROM
                locations l
            WHERE
                l.location = f.location
        ),

        'defense_effectiveness', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'defense_type', ds.type,
                    'effectiveness_rate', ROUND((SUM(CASE WHEN ca.outcome = 'Victory' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)), 2),
                    'avg_enemy_casualties', ROUND(AVG(ca.enemy_casualties), 1),
                    'structure_ids', JSON_ARRAYAGG(DISTINCT ds.structure_id)
                )
            )
            FROM
                defense_structures ds
            LEFT JOIN
                creature_attacks ca ON ds.location_id = ca.location_id
            WHERE
                ds.location = f.location
            GROUP BY
                ds.type
        ),

        'military_readiness_assessment', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'squad_id', ms.squad_id,
                    'squad_name', ms.name,
                    -- Формула снова произвольная
                    'readiness_score', ROUND(
                        (COUNT(DISTINCT sm.dwarf_id) * 0.4 + AVG(ds.level) * 0.3 +
                         (SELECT AVG(st.effectiveness) FROM squad_training st
                          WHERE st.squad_id = ms.squad_id) * 0.3), 2
                    ),
                    'active_members', COUNT(DISTINCT sm.dwarf_id),
                    'avg_combat_skill', ROUND(AVG(ds.level), 1),
                    'combat_effectiveness', (
                        SELECT AVG(sb.outcome = 'Victory')
                        FROM squad_battles sb
                        WHERE sb.squad_id = ms.squad_id
                    ),
                    'response_coverage', (
                        SELECT JSON_ARRAYAGG(
                            JSON_OBJECT(
                                'zone_id', sc.zone_id,
                                'response_time', sc.response_time
                            )
                        )
                        FROM squad_coverage sc
                        WHERE sc.squad_id = ms.squad_id
                    )
                )
            )
            FROM
                military_squads ms
            LEFT JOIN squad_members sm ON ms.squad_id = sm.squad_id
                AND sm.exit_date IS NULL
            LEFT JOIN dwarf_skills ds ON sm.dwarf_id = ds.dwarf_id
                AND ds.skill_id IN (SELECT skill_id FROM skills WHERE category = 'Military')
            WHERE
                ms.fortress_id = f.fortress_id
            GROUP BY
                ms.squad_id, ms.name
        ),

        'security_evolution', (
            SELECT JSON_ARRAYAGG(
                JSON_OBJECT(
                    'year', EXTRACT(YEAR FROM ca.date),
                    'defense_success_rate', ROUND(
                        (SUM(CASE WHEN ca.outcome = 'Victory' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)), 2
                    ),
                    'total_attacks', COUNT(*),
                    'casualties', SUM(ca.casualties),
                    'year_over_year_improvement', ROUND(
                        (SUM(CASE WHEN ca.outcome = 'Victory' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0)) -
                        LAG(SUM(CASE WHEN ca.outcome = 'Victory' THEN 1 ELSE 0 END) * 100.0 / NULLIF(COUNT(*), 0))
                        OVER (ORDER BY YEAR(ca.date)), 2
                    )
                )
            )
            FROM
                creature_attacks ca
            JOIN
                creature_sightings cs ON ca.creature_id = cs.creature_id
            WHERE
                cs.location = f.location
            GROUP BY
                EXTRACT(YEAR FROM ca.date)
            ORDER BY
                EXTRACT(YEAR FROM ca.date)
        )
    )
) AS security_report
FROM fortresses f
