-- name: AddRestaurantVisit :one
INSERT INTO restaurant_visits (user_id, restaurant_id, has_visited)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdateRestaurantVisit :one
UPDATE restaurant_visits
SET has_visited = $3
WHERE
  user_id = $1
  AND restaurant_id = $2
RETURNING *;

-- name: RemoveRestaurantVisit :one
DELETE FROM restaurant_visits
WHERE
  user_id = $1
  AND restaurant_id = $2
RETURNING *;
