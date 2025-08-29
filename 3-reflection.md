Желаемый JSON:

```json
[
  {
    "fortress_id": 1,
    "name": "Mountainhome",
    "location": "Eastern Mountains",
    "founded_year": 205,
    "related_entities": {
      "dwarf_ids": [101, 102, 103, 104, 105],
      "resource_ids": [201, 202, 203],
      "workshop_ids": [301, 302],
      "squad_ids": [401]
    }
  }
]
```

```sql
SELECT 
    f.fortress_id,
    f.name,
    f.location,
    f.founded_year,
    JSON_OBJECT(
        'dwarf_ids', (
            SELECT JSON_ARRAYAGG(d.dwarf_id)
            FROM dwarves d
            WHERE d.fortress_id = f.fortress_id
        ),
        'resource_ids', (
            SELECT JSON_ARRAYAGG(fr.resource_id)
            FROM fortress_resources fr
            WHERE fr.fortress_id = f.fortress_id
        ),
        'workshop_ids', (
            SELECT JSON_ARRAYAGG(w.workshop_id)
            FROM workshops w
            WHERE w.fortress_id = f.fortress_id
        ),
        'squad_ids', (
            SELECT JSON_ARRAYAGG(s.squad_id)
            FROM military_squads s
            WHERE s.fortress_id = f.fortress_id
        )
    ) AS related_entities
FROM 
    fortresses f;
```

JSON_OBJECT - это именно объект в JSON формате с парой `ключ-значение`.
Первое строковое значение в функции и будет ключем, а вот второе своего рода подзапрос, который при этом
содержит своего рода неочевидный JOIN (строчка типа `WHERE d.fortress_id = f.fortress_id` фильтрует только по значению нужного форта).
JSON_ARRAYAGG - это JSON-массив. По смыслу это агрегационная функция, аналогом которой будет `array_agg` из `PostgreSQL` или `group_array` из `Clickhouse`.
Подзапрос "джойнит" все айди, связанные с конкретным `fortress_id` в виде массива.
