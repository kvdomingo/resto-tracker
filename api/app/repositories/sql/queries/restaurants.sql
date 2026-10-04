-- name: GetRestaurant :one
SELECT *
FROM restaurants
WHERE id = $1;

-- name: ListRestaurants :many
SELECT *
FROM restaurants
LIMIT $1 OFFSET $2;

-- name: CreateRestaurant :one
INSERT INTO restaurants (
  created_by_id, name, price_tier, tags, branches,
  instagram_handle, website, menu_url, is_reservation_required
)
VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
RETURNING *;

-- name: UpdateRestaurant :one
UPDATE restaurants
SET
  name = COALESCE(sqlc.narg('name'), name),
  price_tier = COALESCE(sqlc.narg('price_tier'), price_tier),
  tags = COALESCE(sqlc.narg('tags'), tags),
  branches = COALESCE(sqlc.narg('branches'), branches),
  instagram_handle = COALESCE(sqlc.narg('instagram_handle'), instagram_handle),
  website = COALESCE(sqlc.narg('website'), website),
  menu_url = COALESCE(sqlc.narg('menu_url'), menu_url),
  is_reservation_required
  = COALESCE(sqlc.narg('is_reservation_required'), is_reservation_required)
WHERE id = $1
RETURNING *;

-- name: DeleteRestaurant :one
DELETE FROM restaurants
WHERE id = $1
RETURNING *;
