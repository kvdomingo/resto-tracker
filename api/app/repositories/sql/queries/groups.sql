-- name: ListAllGroups :many
SELECT *
FROM groups
LIMIT
  $1
  OFFSET $2;

-- name: ListMyGroups :many
SELECT g.*
FROM groups g
  JOIN group_memberships m
    ON
      m.group_id = g.id
      AND m.user_id = $1
LIMIT
  $2
  OFFSET $3;

-- name: GetGroup :one
SELECT
  g.*,
  JSONB_AGG(m.*) AS members
FROM groups g
  JOIN group_memberships m
    ON m.group_id = g.id
WHERE
  g.id = $1
  AND g.created_by_id = $2
GROUP BY g.id;

-- name: CreateGroup :one
WITH
  new_group AS (
    INSERT INTO groups (created_by_id, name)
    VALUES ($1, $2)
    RETURNING *
  ),

  new_membership AS (
    INSERT INTO group_memberships (user_id, group_id)
    SELECT
      $1 AS user_id,
      g.id AS group_id
    FROM new_group g
  )

SELECT *
FROM new_group;

-- name: UpdateGroup :one
UPDATE groups
SET name = $3
WHERE
  id = $1
  AND created_by_id = $2
RETURNING *;

-- name: DeleteGroup :one
DELETE FROM groups
WHERE
  id = $1
  AND created_by_id = $2
RETURNING *;
