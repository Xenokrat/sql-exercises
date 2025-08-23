-- 1. Получить информацию о всех гномах, которые входят в какой-либо отряд, вместе с информацией об их отрядах. 
SELECT
    d.dwarf_id   AS dwarf_id,
    d.name       AS dwarf_name,
    d.age        AS age,
    d.profession AS profession,
    s.name       AS squad_name,
    s.mission    AS mission
FROM
    dwarves d
INNER JOIN
    squads s ON d.squad_id = s.squad_id
;


-- 2. Найти всех гномов с профессией "miner", которые не состоят ни в одном отряде. 
SELECT
    dwarf_id,
    dwarf_name,
    age,
    profession
FROM
    dwarves
WHERE
    profession = 'miner'
    AND squad_id IS NULL
;

-- 3. Получить все задачи с наивысшим приоритетом, которые находятся в статусе "pending". 
WITH
    -- Наивысший приоритет
    _MAX_PRIORITY AS (
        SELECT
            max(priority) AS max_priority
        FROM
            tasks
    )
SELECT
    task_id,
    description,
    priority,
    assigned_to,
    status,
FROM
    tasks
WHERE
    status = 'pending'
    AND priority = (SELECT max_priority FROM _MAX_PRIORITY)
;
    
-- 4. Для каждого гнома, который владеет хотя бы одним предметом, получить количество предметов, которыми он владеет.     
SELECT
    d.dwarf_id AS dwarf_id
    d.name     AS dwarf_name,
    count(*)   AS item_count
FROM
    dwarves d
INNER JOIN
    items i ON d.dwarf_id = i.owner_id    
GROUP BY
    dwarf_id,
    dwarf_name
;

-- 5. Получить список всех отрядов и количество гномов в каждом отряде. Также включите в выдачу отряды без гномов. 
SELECT
    s.squad_id,
    s.name AS squad_name,
    s.mission,
    COALESCE(count(*), 0) AS squad_members_count
FROM
    squads s
LEFT JOIN
    dwarves d ON s.squad_id = d.squad_id
GROUP BY
    s.squad_id,
    s.name,
    s.mission
;

-- 6. Получить список профессий с наибольшим количеством незавершённых задач ("pending" и "in_progress") у гномов этих профессий.
WITH
    _PROFESSION_STAT AS (
        SELECT
            d.profession,
            count(DISTINCT task_id) AS incomplete_task_count
        FROM
            tasks t
        INNER JOIN
            dwarves d ON t.assigned_to = d.dwarf_id
        WHERE
            t.status IN ('pending', 'in_progress')
        GROUP BY
            d.profession
    ),
    _MAX_INCOMPLETE AS (
        SELECT
            max(incomplete_task_count) AS max_incomplete_tasks
        FROM
            _PROFESSION_STAT
    )
SELECT
    profession,
    incomplete_task_count
FROM
    _PROFESSION_STAT
WHERE
    incomplete_task_count = (SELECT max_incomplete_tasks FROM _MAX_INCOMPLETE)
;
    

-- 7. Для каждого типа предметов узнать средний возраст гномов, владеющих этими предметами. 
SELECT
    i.type     AS item_type,
    avg(d.age) AS average_owner_age -- предполагаю, что если у типа предмета нет владельцев, оставим NULL
FROM
    items i
LEFT JOIN
    dwarves d ON i.owner_id = d.dwarf_id   
GROUP BY
    i.type
;

-- 8. Найти всех гномов старше среднего возраста (по всем гномам в базе), которые не владеют никакими предметами. 
WITH
    _AVG_AGE AS (
        SELECT
            avg(age) AS avg_age
        FROM
            dwarves
    )
SELECT
    d.dwarf_id,
    d.name
FROM
    dwarves d
LEFT JOIN
    items i ON d.dwarf_id = i.owner_id
WHERE
    i.owner_id IS NULL
    AND d.age > (SELECT avg_age FROM _AVG_AGE)
;
