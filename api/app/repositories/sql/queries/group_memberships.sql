-- name: AddToGroup :batchmany
INSERT INTO group_memberships (user_id, group_id)
VALUES ($1, $2)
ON CONFLICT DO NOTHING
RETURNING *;

-- name: RemoveFromGroup :many
DELETE FROM group_memberships
WHERE
  user_id = $1
  AND group_id = $2
RETURNING *;
