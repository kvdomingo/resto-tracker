-- name: AddToGroup :batchmany
WITH
  owned_groups AS (
    SELECT id
    FROM groups
    WHERE
      id = $1
      AND created_by_id = $2
  )

INSERT INTO group_memberships (user_id, group_id)
SELECT
  $3 AS user_id,
  id AS group_id
FROM owned_groups
ON CONFLICT DO NOTHING
RETURNING *;

-- name: RemoveFromGroup :batchmany
DELETE FROM group_memberships
WHERE
  user_id = $3
  AND group_id IN (
    SELECT id
    FROM groups
    WHERE
      id = $1
      AND created_by_id = $2
  )
RETURNING *;
