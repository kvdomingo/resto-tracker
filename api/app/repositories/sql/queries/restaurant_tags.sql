-- name: AddRestaurantTags :many
INSERT INTO restaurant_tags (restaurant_id, tag_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING
RETURNING *;

-- name: RemoveRestaurantTags :many
DELETE FROM restaurant_tags
WHERE
  restaurant_id = $1
  AND tag_id = $2
RETURNING *;
