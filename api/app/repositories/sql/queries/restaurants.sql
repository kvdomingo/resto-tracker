-- name: GetRestaurant :one
SELECT
  r.*,
  JSONB_AGG(
    JSON_BUILD_OBJECT(
      'id', b.id,
      'restaurant_id', b.restaurant_id,
      'label', b.label,
      'geography', JSONB_BUILD_OBJECT(
        'latitude', ST_Y(b.geography::geometry),
        'longitude', ST_X(b.geography::geometry)
      )
    )
    ORDER BY b.id
  )::restaurant_branch_list AS branches,
  JSONB_AGG(t.name) AS tags
FROM restaurants r
  LEFT JOIN restaurant_branches b
    ON b.restaurant_id = r.id
  LEFT JOIN restaurant_tags rt
    ON rt.restaurant_id = r.id
  LEFT JOIN tags t
    ON t.id = rt.tag_id
WHERE r.id = $1
GROUP BY r.id;

-- name: ListRestaurants :many
SELECT *
FROM restaurants
LIMIT $1 OFFSET $2;

-- name: ListRestaurantsInArea :many
SELECT
  r.*,
  JSONB_AGG(
    JSON_BUILD_OBJECT(
      'id', b.id,
      'restaurant_id', b.restaurant_id,
      'label', b.label,
      'geography', JSONB_BUILD_OBJECT(
        'latitude', ST_Y(b.geography::geometry),
        'longitude', ST_X(b.geography::geometry)
      )
    )
    ORDER BY b.id
  )::restaurant_branch_list AS branches
FROM restaurants r
  JOIN restaurant_branches b ON r.id = b.restaurant_id
WHERE
  b.geography && ST_MAKEENVELOPE(@w::float, @s::float, @e::float, @n::float, 4326)
GROUP BY r.id
ORDER BY r.id
LIMIT sqlc.arg('limit') OFFSET sqlc.arg('offset');

-- name: CreateRestaurant :one
INSERT INTO restaurants (
  created_by_id, name, price_tier, instagram_handle,
  website, menu_url, is_reservation_required
)
VALUES ($1, $2, $3, $4, $5, $6, $7)
RETURNING *;

-- name: UpdateRestaurant :one
UPDATE restaurants
SET
  name = COALESCE(sqlc.narg('name'), name),
  price_tier = COALESCE(sqlc.narg('price_tier'), price_tier),
  instagram_handle = COALESCE(sqlc.narg('instagram_handle'), instagram_handle),
  website = COALESCE(sqlc.narg('website'), website),
  menu_url = COALESCE(sqlc.narg('menu_url'), menu_url),
  is_reservation_required = COALESCE(
    sqlc.narg('is_reservation_required'),
    is_reservation_required
  )
WHERE id = $1
RETURNING *;

-- name: DeleteRestaurant :one
DELETE FROM restaurants
WHERE id = $1
RETURNING *;
