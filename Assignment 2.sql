CREATE TABLE runners (
  runner_id SERIAL PRIMARY KEY,
  registration_date DATE
);

INSERT INTO runners (runner_id, registration_date) VALUES
(1, '2025-06-01'),
(2, '2025-06-05'),
(3, '2025-06-10'),
(4, '2025-06-15');

CREATE TABLE pizza_names (
  pizza_id SERIAL PRIMARY KEY,
  pizza_name VARCHAR(50)
);

INSERT INTO pizza_names (pizza_id, pizza_name) VALUES
(1, 'Margherita'),
(2, 'Paneer Tikka');

CREATE TABLE pizza_ingredients (
  ingredient_id SERIAL PRIMARY KEY,
  ingredient_name VARCHAR(50)
);

INSERT INTO pizza_ingredients (ingredient_id, ingredient_name) VALUES
(1, 'Cheese'),
(2, 'Tomato'),
(3, 'Basil'),
(4, 'Paneer'),
(5, 'Capsicum'),
(6, 'Olives');

CREATE TABLE pizza_recipes (
  pizza_id INT,
  ingredient_id INT,
  PRIMARY KEY (pizza_id, ingredient_id),
  FOREIGN KEY (pizza_id) REFERENCES pizza_names(pizza_id),
  FOREIGN KEY (ingredient_id) REFERENCES pizza_ingredients(ingredient_id)
);

INSERT INTO pizza_recipes (pizza_id, ingredient_id) VALUES
(1, 1), -- Margherita -> Cheese
(1, 2), -- Margherita -> Tomato
(1, 3), -- Margherita -> Basil
(2, 1), -- Paneer Tikka -> Cheese
(2, 4), -- Paneer Tikka -> Paneer
(2, 5); -- Paneer Tikka -> Capsicum

CREATE TABLE customer_orders (
  order_item_id SERIAL PRIMARY KEY,
  order_id INT,
  customer_id INT,
  pizza_id INT,
  exclusions VARCHAR(100),
  extras VARCHAR(100),
  order_time TIMESTAMP,
  FOREIGN KEY (pizza_id) REFERENCES pizza_names(pizza_id)
);

INSERT INTO customer_orders (order_id, customer_id, pizza_id, exclusions, extras, order_time) VALUES
(1, 201, 1, '', '', '2025-06-20 18:00:00'),
(2, 202, 1, '', '', '2025-06-20 18:05:00'),
(3, 203, 2, '', '5', '2025-06-21 19:30:00'),
(3, 203, 1, '4', '', '2025-06-21 19:30:00'),
(4, 204, 2, '', '', '2025-06-22 20:00:00'),
(5, 205, 1, '4', '5', '2025-06-22 21:15:00'),
(6, 202, 2, '', '6', '2025-06-23 17:45:00'),
(7, 206, 1, '', '', '2025-06-23 18:30:00'),
(8, 207, 2, '', '1,6', '2025-06-23 19:15:00');

CREATE TABLE runner_orders (
  order_id INT,
  runner_id INT,
  pickup_time TIMESTAMP,
  distance_km NUMERIC(5,2),
  duration_mins INT,
  cancellation VARCHAR(50),
  FOREIGN KEY (runner_id) REFERENCES runners(runner_id)
);

INSERT INTO runner_orders (order_id, runner_id, pickup_time, distance_km, duration_mins, cancellation) VALUES
(1, 1, '2025-06-20 18:10:00', 5.2, 15, ''),
(2, 2, '2025-06-20 18:15:00', 3.8, 12, ''),
(3, 1, '2025-06-21 19:40:00', 7.5, 20, ''),
(4, 3, NULL, NULL, NULL, 'Restaurant cancelled'),
(5, 4, '2025-06-22 21:25:00', 4.5, 14, ''),
(6, 2, '2025-06-23 17:55:00', 6.0, 18, ''),
(7, 3, '2025-06-23 18:40:00', 2.5, 9, ''),
(8, 1, '2025-06-23 19:25:00', 8.2, 22, '');

Q1 How many runners signed up each week? (Assume week starts Monday.) 

SELECT
  DATE_TRUNC('week', registration_date) AS week_start,
  COUNT(*) AS runners_signed_up
FROM runners
GROUP BY week_start
ORDER BY week_start;

Q2 Average time (minutes) between runner registration and first pickup

SELECT
  ROUND(
    AVG(
      EXTRACT(EPOCH FROM (ro.pickup_time - r.registration_date)) / 60
    ),
    2
  ) AS avg_minutes_to_first_pickup
FROM runners r
JOIN runner_orders ro
  ON r.runner_id = ro.runner_id
WHERE ro.pickup_time IS NOT NULL;

Q3 What’s the successful delivery count per runner?

SELECT
  runner_id,
  COUNT(*) AS successful_deliveries
FROM runner_orders
WHERE cancellation = ''
GROUP BY runner_id
ORDER BY runner_id;

Q4 Delivery success rate per runner (ratio of non-cancelled to total assigned orders)?

SELECT
  runner_id,
  ROUND(
    SUM(CASE WHEN cancellation = '' THEN 1 ELSE 0 END)::NUMERIC
    / COUNT(*),
    2
  ) AS success_rate
FROM runner_orders
GROUP BY runner_id
ORDER BY runner_id;

Q5 Average speed per runner (distance/duration); any noticeable trends? 

SELECT
  runner_id,
  ROUND(AVG(distance_km / duration_mins), 2) AS avg_speed
FROM runner_orders
WHERE cancellation = ''
GROUP BY runner_id
ORDER BY runner_id;

B. Order & Delivery Insights 

Q1 Total number of pizzas ordered.

SELECT COUNT(*) AS total_pizzas_ordered
from customer_orders;

Q2 Unique customer orders count. 

SELECT
COUNT(DISTINCT order_id)AS unique_orders
from customer_orders;

Q3 Average waiting time (order_time to pickup_time) for successful deliveries

SELECT
  ROUND(
    AVG(EXTRACT(EPOCH FROM (ro.pickup_time - co.order_time)) / 60),
    2
  ) AS avg_wait_time_minutes
FROM customer_orders co
JOIN runner_orders ro
  ON co.order_id = ro.order_id
WHERE ro.cancellation = '';

Q4 Difference between longest and shortest delivery durations

SELECT
  MAX(duration_mins) - MIN(duration_mins) AS duration_difference
FROM runner_orders
WHERE cancellation = '';


-- C. Ingredient Optimization

Q1  List standard ingredients per pizza (by name). 

SELECT
  pn.pizza_name,
  STRING_AGG(pi.ingredient_name, ', ') AS ingredients
FROM pizza_names pn
JOIN pizza_recipes pr
  ON pn.pizza_id = pr.pizza_id
JOIN pizza_ingredients pi
  ON pr.ingredient_id = pi.ingredient_id
GROUP BY pn.pizza_name
ORDER BY pn.pizza_name;

Q2 Most commonly added extra ingredient (name

SELECT
  pi.ingredient_name,
  COUNT(*) AS extra_count
FROM customer_orders co
JOIN pizza_ingredients pi
  ON pi.ingredient_id = ANY(STRING_TO_ARRAY(co.extras, ',')::INT[])
WHERE co.extras <> ''
GROUP BY pi.ingredient_name
ORDER BY extra_count DESC
LIMIT 1;

Q3 Most commonly excluded ingredient. 

SELECT
  pi.ingredient_name,
  COUNT(*) AS exclusion_count
FROM customer_orders co
JOIN pizza_ingredients pi
  ON pi.ingredient_id = ANY(STRING_TO_ARRAY(co.exclusions, ',')::INT[])
WHERE co.exclusions <> ''
GROUP BY pi.ingredient_name
ORDER BY exclusion_count DESC
LIMIT 1;

Q4 Total count of each ingredient used in delivered pizzas, sorted descending. 

SELECT
  pi.ingredient_name,
  COUNT(*) AS total_used
FROM customer_orders co
JOIN runner_orders ro
  ON co.order_id = ro.order_id
JOIN pizza_recipes pr
  ON co.pizza_id = pr.pizza_id
JOIN pizza_ingredients pi
  ON pr.ingredient_id = pi.ingredient_id
WHERE ro.cancellation = ''
GROUP BY pi.ingredient_name
ORDER BY total_used DESC;



. 








 
 







