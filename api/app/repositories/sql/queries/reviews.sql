-- name: ListReviewsForRestaurant :many
SELECT
  r.id,
  r.created_at,
  u.id AS author_id,
  u.name AS author_name,
  r.restaurant_id,
  r.is_anonymous,
  r.content,
  r.rating
FROM reviews r
  LEFT JOIN users u
    ON
      u.id = r.author_id
      AND NOT r.is_anonymous
WHERE restaurant_id = $3
LIMIT
  $1
  OFFSET $2;

-- name: CreateReview :one
INSERT INTO reviews (author_id, restaurant_id, is_anonymous, content, rating)
VALUES ($1, $2, $3, $4, $5)
RETURNING *;

-- name: UpdateReview :one
UPDATE reviews
SET
  is_anonymous = COALESCE(sqlc.narg('is_anonymous'), is_anonymous),
  content = COALESCE(
    NULLIF(sqlc.narg('content')::TEXT, ''),
    content
  ),
  rating = COALESCE(sqlc.narg('rating'), rating)
WHERE
  id = @id
  AND author_id = @author_id
RETURNING *;

-- name: DeleteReview :one
DELETE FROM reviews
WHERE
  id = $1
  AND author_id = $2
RETURNING *;
