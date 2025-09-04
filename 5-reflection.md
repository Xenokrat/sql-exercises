# Рефлексия 5

В этот раз много отличий :).

В эталоне:
```sql
COUNT(DISTINCT es.site_id) AS discovered_sites
```

В моём решении я посчитал только "открытые локации", т.е. ели они новые
```sql
COUNT(DISTINCT site_id) FILTER (WHERE e.departure_date < es.discovery_date) AS discovered_sites,
```

Я предположил, что outcome будет `bool` полем сразу, поэтому не производил перевод:
в эталоне:
```sql
SUM(CASE WHEN ec.outcome = 'Favorable' THEN 1 ELSE 0 END) AS favorable_encounters,
```

В эталоне `skill_progression` считался как сумма разниц в скилле для каждого из индивидуальных
гномов. Я предположил, что можно просто просуммировать навык всех гномов до экспеции и после, и
посчитать разницу, мне кажется, что это приемлимое решение. Поэтому обошёлся без второго подзапроса.

Также не думал, что экспедиции могу быть без участников или без посещенных локаций,
поэтому оставил `INNER JOIN`, но в остальных случаях использовал `LEFT`, также поэтому
не всегда переводил возможные `NULL` в 0.

Вычисление overall_success_score выглядит более сложным, чем то что я придумал:
```sql
-- Эталон
ROUND(
    (es.survivors::DECIMAL / es.total_members) * 0.3 +
    (es.artifacts_value / 1000) * 0.25 +
    (es.discovered_sites * 0.15) +
    COALESCE((es.favorable_encounters::DECIMAL /
        NULLIF(es.total_encounters, 0)), 0) * 0.15 +
    COALESCE((sp.total_skill_improvement / es.total_members), 0) * 0.15,
    2
) AS overall_success_score,

-- VS
((survival_rate / 100) * 0.5
+ (encounter_success_rate / 100) * 0.5) AS overall_success_score
```

Различные `rate` показатели, вроде:
```sql
ROUND((es.survivors::DECIMAL / es.total_members) * 100, 2) AS survival_rate
```

я считаю чуть проще, используя трюк, которому инога учат аналитиков - если мы переведём булево поле
в int и возьмем среднее, то получится как раз значение rate-%:

```sql
round(avg(em.survived::int) * 100, 2)
```

В остальном решение соотносится с эталонным.
