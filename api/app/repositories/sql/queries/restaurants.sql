-- name: GetRestaurant :one
SELECT *
FROM restaurants
WHERE id = $1;

-- name: ListRestaurants :many
SELECT *
FROM restaurants
LIMIT $1 OFFSET $2;
