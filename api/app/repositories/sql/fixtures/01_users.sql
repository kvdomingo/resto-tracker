INSERT INTO users (id, idp_user_id, email, name)
VALUES ('system', 'system', 'hello@kvd.studio', 'System')
ON CONFLICT DO NOTHING;
