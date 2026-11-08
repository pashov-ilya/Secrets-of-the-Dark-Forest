/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Пашов Илья
 * Дата: 23.11.2026
*/

-- Часть 1. Исследовательский анализ данных

-- Задача 1. Исследование доли платящих игроков

-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь


/* подзапрос вычислят количество платящих игроков всего, запрос выводит их количество,
 а также количество всего игроков и долю платящих игроков в процентах, округленную до 3х знаков. */

WITH donors AS (
	SELECT COUNT(id) AS paying_players
	FROM fantasy.users 
	WHERE payer = 1
)

SELECT COUNT(u.id) AS total_players,  d.paying_players,
	ROUND(d.paying_players::numeric / COUNT(u.id) * 100, 3) AS "Share of paying players"
FROM fantasy.users u CROSS JOIN donors d
GROUP BY d.paying_players;


-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь

/*первый подзапрос вычисляет количество платящих игроков для каждой расы.
  Второй подзапрос вычисляет общее количество игроков для каждой расы.
  Основной запрос выводит для каждой расы количество платящих игроков, общее количество игроков и долю платящих игроков в процентах.
  Запрос отсортирован по расам в алфавитном порядке.  */

WITH race_paying_donors AS (
	SELECT r.race, COUNT(r.race) AS payer_per_race
	FROM fantasy.users u JOIN fantasy.race r
		USING(race_id)
	WHERE u.payer = 1
	GROUP BY r.race
),
total_race_donors AS (
	SELECT r.race, COUNT(r.race) AS total_per_race
	FROM fantasy.users u JOIN fantasy.race r
		USING(race_id)
	GROUP BY r.race
)
SELECT rpd.race, rpd.payer_per_race, trd.total_per_race,
	ROUND(rpd.payer_per_race::numeric / trd.total_per_race * 100, 2) AS "paying player rate"
FROM race_paying_donors rpd
JOIN total_race_donors trd
	ON rpd.race = trd.race
ORDER BY 1;

-- Задача 2. Исследование внутриигровых покупок

-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь

/* запрос выводит общее количество покупок, суммарную, минимальную, максимальную и среднюю стоимость,
  медиану и стандартное отклонение. */
SELECT COUNT(amount) AS total_purchases, SUM(amount) AS total_amount,
	MIN(amount) AS min_amount, MAX(amount) AS max_amount,
	AVG(amount) AS avg_amount, PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
	STDDEV(amount) AS stand_dev_amount
FROM fantasy.events;

-- дополнитеьный анализ без покупок с нулевой стоимостью

SELECT COUNT(amount) AS total_purchases, SUM(amount) AS total_amount,
	MIN(amount) AS min_amount, MAX(amount) AS max_amount,
	AVG(amount) AS avg_amount, PERCENTILE_DISC(0.5) WITHIN GROUP(ORDER BY amount) AS median_amount,
	STDDEV(amount) AS stand_dev_amount
FROM fantasy.events
WHERE amount > 0;

-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь

/* запрос выводит количество покупок с нулевой стоимостью,
  а также долю таких покупок от общего количества в % */

-- добавил общее количество. Сделал это таким способом, чтобы не копировать ваш. Спасибо за filter, рассмотрю такой способ фильтрации, выглядит очень удобно!
SELECT (SELECT COUNT(amount) FROM fantasy.events) AS total_amount, COUNT(amount) AS zero_cost,
	ROUND(COUNT(amount)::numeric / (SELECT COUNT(amount) FROM fantasy.events) * 100, 2) AS share_zero_cost 
FROM fantasy.events
WHERE amount > 0;

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь

/* 1) первый подзапрос считал количество платных покупок для каждого эпического предмета, 
 долю этих покупок от общего количества платных покупок в %. При этом бесплатные покупки с amount = 0 исключаются из анализа.
   2) Второй подзапрос формирует список уникальных сочетаний игрока и предмета,
исключая покупки с нулевой стоимостью. Если игрок покупал один предмет несколько раз,
он всё равно будет указан для этого предмета только один раз.
   3) Третий подзапрос вычисляет количество уникальных игроков,совершивших платные покупки каждого предмета.
Для подсчёта используется подзапрос players, в котором каждое сочетание игрока и предмета встречается только один раз.
   4) Четвертый подзапрос считает общее количество уникальных игроков, совершивших хотя бы одну платную внутриигровую покупку.
   
Основной запрос объединяет рассчитанные показатели популярности эпических предметов.
Для каждого предмета выводятся его название, количество платных покупок, доля предмета среди всех платных покупок в %
и доля уникальных игроков в %, купивших предмет, среди всех игроков,
совершивших хотя бы одну платную покупку. Результаты сортируется сначала по количетсву покупок в порядке убывания,
 затем по названию предметов в алфавитном порядке.*/
WITH sales AS (SELECT e.item_code, COUNT(e.item_code) AS total_sales,
	ROUND(COUNT(e.item_code)::numeric / 
		(SELECT COUNT(item_code) FROM fantasy.events WHERE amount > 0) * 100, 2) AS total_sales_share
FROM fantasy.items i JOIN fantasy.events e USING(item_code)
WHERE e.amount > 0
GROUP BY e.item_code),
  players AS (
	SELECT e.id, e.item_code
	FROM fantasy.events e
	WHERE e.amount > 0
	GROUP BY e.id, e.item_code
),
 players_per_item AS (
SELECT item_code, COUNT(*) AS players_count
FROM players
GROUP BY item_code
),
 total_players AS (
SELECT COUNT(*) AS total_players
FROM (
	SELECT id FROM fantasy.events
	WHERE amount > 0
	GROUP BY id)
)
SELECT i.game_items, s.total_sales, s.total_sales_share,
	ROUND(ppi.players_count::numeric / tp.total_players * 100, 2) AS players_share
FROM players_per_item ppi
JOIN fantasy.items i USING (item_code)
JOIN sales s ON s.item_code = i.item_code
CROSS JOIN total_players tp
ORDER BY 2 DESC, 1 ASC;


-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь

/*1) Первый подзапрос total_p считает общее количество зарегистрированных игроков для каждой игровой расы.
Группировка по race_id позволяет получить отдельное значение для каждой расы.

  2) Второй подзапрос active_p определяет количество уникальных активных игроков каждой расы,совершивших хотя бы одну покупку с ненулевой стоимостью.
 Дополнительно рассчитывается доля активных игроков от общего количества зарегистрированных игроков соответствующей расы, округленная до пяти знаков.

  3) Третий подзапрос active_d определяет количество уникальных платящих игроков каждой расы, совершивших хотя бы одну внутриигровую покупку с ненулевой стоимостью.
Для отбора платящих игроков используется условие payer = 1, а условие amount > 0 исключает бесплатные покупки.

  4) Четвёртый подзапрос active_d_s рассчитывает долю платящих игроков среди активных игроков каждой расы.
Для этого количество активных платящих игроков из подзапроса active_d делится на количество активных игроков из подзапроса active_p.
Результат округляется до трёх знаков после запятой.

Основной запрос объединяет таблицы events, users, race и результаты подзапросов active_p и active_d_s, чтобы получить итоговые показатели
активности игроков в разрезе игровых рас.
 
Выводятся названия рас; общее количество игроков; количество игроков,
осуществлявших внутриигровые покупки(активные игроки), и их доля; доля платящих игроков среди тех, кто делал внутриигровую покупку;
среднее количество покупок на одного игрока, совершившего внутриигровые покупки;
среднюю стоимость одной покупки на одного игрока, совершившего внутриигровые покупки;
среднюю суммарная стоимость всех покупок на одного игрока, совершившего внутриигровые покупки.

Показатель avg_purchase_per_player рассчитывает среднее количество покупок на одного активного игрока.
Для этого общее количество покупок с ненулевой стоимостью делится на количество активных игроков соответствующей расы.

Показатель avg_cost_per_player рассчитывает среднюю стоимость одной покупки на одного игрока с ненулевой стоимостью с помощью функции AVG(amount).
В расчёт включаются все покупки соответствующей расы, а результат округляется до двух знаков после запятой.

Показатель avg_total_cost_per_player рассчитывает среднюю суммарную стоимость покупок на одного активного игрока.
Для этого общая стоимость всех покупок с ненулевой стоимостью делится на количество активных игроков соответствующей расы.
Результат округляется до двух знаков после запятой.

Условие WHERE amount > 0 исключает из расчётов покупки с нулевой стоимостью, чтобы бесплатные покупки не влияли на итоговые показатели.
Группировка GROUP BY по названию расы и рассчитанным показателям позволяет получить одну итоговую строку для каждой расы
с соответствующими значениями всех требуемых метрик.
*/
WITH total_p AS (
	SELECT race_id, COUNT(id) AS total_players
	FROM fantasy.users 
	GROUP BY race_id
),
  active_p AS (
 	SELECT t.race_id, COUNT(DISTINCT e.id) AS active_players,
	t.total_players, ROUND(COUNT(DISTINCT e.id)::numeric / t.total_players * 100, 2) AS active_players_share
	FROM fantasy.events e JOIN fantasy.users u USING(id)
	JOIN total_p t USING(race_id)
	WHERE e.amount > 0
	GROUP BY t.race_id, t.total_players
),
 active_d AS (
	SELECT u.race_id, COUNT(DISTINCT e.id) AS active_donors
	FROM fantasy.events e JOIN fantasy.users u 
	USING(id)
	WHERE u.payer = 1 AND e.amount > 0
	GROUP BY race_id
),
 active_d_s AS (
 	SELECT a_p.race_id,
 		ROUND(a_d.active_donors::numeric / a_p.active_players * 100, 2) AS active_donors_share
	FROM active_d a_d JOIN active_p a_p USING(race_id)
)
SELECT r.race, ap.total_players, ap.active_players,
	ap.active_players_share, ads.active_donors_share,
	ROUND(COUNT(e.amount)::numeric/ap.active_players, 2) AS avg_purchase_per_player,
	ROUND(AVG(e.amount)::numeric, 2) AS avg_cost_per_player,
	ROUND(SUM(e.amount)::numeric / ap.active_players, 2) AS avg_total_cost_per_player
FROM fantasy.events e JOIN fantasy.users u USING(id)
	JOIN fantasy.race r USING(race_id)
	JOIN active_p ap USING(race_id)
	JOIN active_d_s ads USING(race_id)
WHERE e.amount > 0
GROUP BY r.race, ap.total_players, ap.active_players,
	ap.active_players_share, ads.active_donors_share

	



	

