-- name: AddRestaurantBranches :batchmany
INSERT INTO restaurant_branches (restaurant_id, geography, label)
VALUES ($1, $2, $3)
RETURNING *;

-- name: DeleteRestaurantBranches :batchmany
DELETE FROM restaurant_branches
WHERE id = $1
RETURNING *;

-- name: UpdateRestaurantBranches :batchmany
UPDATE restaurant_branches
SET
  geography = COALESCE(sqlc.narg('geography'), geography),
  label = COALESCE(sqlc.narg('label'), label)
WHERE id = @id
RETURNING *;
