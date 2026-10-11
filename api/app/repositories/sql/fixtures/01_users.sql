INSERT INTO users (id, idp_user_id, email, name)
VALUES (
  'system', 'user-test-2b07b28c-ae86-45ec-8d9c-49dee0f711b7',
  'hello@kvd.studio', 'Kenneth Domingo'
)
ON CONFLICT DO NOTHING;
