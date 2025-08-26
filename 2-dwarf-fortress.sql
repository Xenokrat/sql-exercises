-- 1. Найдите все отряды, у которых нет лидера.
SELECT
    squad_id,
    name AS squad_name,
FROM
    squads
WHERE
    learder_id IS NULL
;

-- 2. Получите список всех гномов старше 150 лет, у которых профессия "Warrior".
SELECT
    dwarf_id,
    name AS dwarf_name,
    age
FROM
    dwarves
WHERE
    age > 150
    AND profession = 'Warrior'
 ;

-- 3. Найдите гномов, у которых есть хотя бы один предмет типа "weapon".
SELECT
    dwarf_id,
    name AS dwarf_name
FROM
    dwarves
WHERE
    dwarf_id IN (
        SELECT
            DISTINCT
            owner_id
        FROM
            items
        WHERE
            type = 'weapon'
    )
    

-- 4. Получите количество задач для каждого гнома, сгруппировав их по статусу.
SELECT
    dwarf_id,
    name                    AS dwarf_name,
    status,
    COUNT(DISTINCT task_id) AS task_count
FROM
    tasks t
INNER JOIN
    dwarves d ON t.assigned_to = d.dwarf_id
GROUP BY
    dwarf_id,
    dwarf_name,
    status
 ;


-- 5. Найдите все задачи, которые были назначены гномам из отряда с именем "Guardians".
WITH
    _GUARDIANS_DWARVES AS (
        SELECT
            DISTINCT
            dwarf_id
        FROM
            dwarves
        WHERE
            squad_id IN (SELECT squad_id FROM squads WHERE name = 'Guardians')
    )
SELECT
    task_id,
    description,
    status
FROM
    tasks
WHERE
    assigned_to IN (SELECT dwarf_id FROM _GUARDIANS_DWARVES)
;


-- 6. Выведите всех гномов и их ближайших родственников, указав тип родственных отношений. 
SELECT
    DISTINCT
    d1.name        AS dwarf_name,
    d2.name        AS relative_name,
    r.relationship AS relationship 
 FROM
    relationships r
 INNER JOIN
     dwarves d1 ON r.dwarf_id = d1.dwarf_id
 INNER JOIN
     dwarves d2 ON r.related_to = d1.dwarf_id
 ORDER BY
    dwarf_name
 ;
