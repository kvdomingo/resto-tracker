-- migrate:up
CREATE DOMAIN restaurant_branch_list AS JSONB;

-- migrate:down
DROP DOMAIN restaurant_branch_list;
