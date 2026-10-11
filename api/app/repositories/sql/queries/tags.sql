-- name: ListTags :many
SELECT *
FROM tags
LIMIT
  $1
  OFFSET $2;

-- name: SearchTags :many
SELECT *
FROM tags
WHERE $3 % name
LIMIT
  $1
  OFFSET $2;

-- name: CreateTag :one
INSERT INTO tags (created_by_id, name)
VALUES ($1, $2)
RETURNING *;

-- name: UpdateTag :one
UPDATE tags
SET name = $2
WHERE id = $1
RETURNING *;

-- name: DeleteTag :one
DELETE FROM tags
WHERE id = $1
RETURNING *;
