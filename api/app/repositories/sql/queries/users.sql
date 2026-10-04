-- name: GetUserById :one
SELECT *
FROM users
WHERE id = $1;

-- name: GetUserByIdpId :one
SELECT *
FROM users
WHERE idp_user_id = $1;

-- name: CreateUser :one
INSERT INTO users (idp_user_id, email, name)
VALUES ($1, $2, $3)
RETURNING *;

-- name: UpdateUser :one
UPDATE users
SET
  idp_user_id = COALESCE(sqlc.narg('idp_user_id'), idp_user_id),
  email = COALESCE(sqlc.narg('email'), email),
  name = COALESCE(sqlc.narg('name'), name)
WHERE
  id = $1
RETURNING *;

-- name: DeleteUser :one
DELETE FROM users
WHERE id = $1
RETURNING *;
