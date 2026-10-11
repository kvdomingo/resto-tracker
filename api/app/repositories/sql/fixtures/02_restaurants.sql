INSERT INTO restaurants (
  id, created_by_id, name, price_tier, instagram_handle,
  website, menu_url, is_reservation_required
)
VALUES (
  '01KZK4AW296W26ZR0JMYPW71S0', 'system', 'Cafe Breton', 2, 'cafebretonph',
  NULL, NULL, FALSE
),
(
  '01KZK4B0R1NKKGG2Y2E1NWCATK', 'system', 'Mamou', 3, 'mymamou',
  NULL, NULL, FALSE
)
ON CONFLICT (id) DO UPDATE
  SET
    name = excluded.name,
    price_tier = excluded.price_tier,
    instagram_handle = excluded.instagram_handle,
    website = excluded.website,
    menu_url = excluded.menu_url,
    is_reservation_required = excluded.is_reservation_required;

INSERT INTO tags (id, created_by_id, name)
VALUES
('01M4N5N9Z5BEF4QCD9256T4HPK', 'system', 'french'),
('01M4N5S1P9JVXHRM53XQSPQV1J', 'system', 'pastries'),
('01M4N5SFBMV0A5Q99WTCSB8KE0', 'system', 'steak'),
('01M4N5SK2XZ754BA3S2CMGJY4F', 'system', 'italian')
ON CONFLICT (id) DO UPDATE
  SET
    created_by_id = excluded.created_by_id,
    name = excluded.name;

INSERT INTO restaurant_tags (restaurant_id, tag_id)
VALUES
('01KZK4AW296W26ZR0JMYPW71S0', '01M4N5N9Z5BEF4QCD9256T4HPK'),
('01KZK4AW296W26ZR0JMYPW71S0', '01M4N5S1P9JVXHRM53XQSPQV1J'),
('01KZK4B0R1NKKGG2Y2E1NWCATK', '01M4N5SFBMV0A5Q99WTCSB8KE0'),
('01KZK4B0R1NKKGG2Y2E1NWCATK', '01M4N5SK2XZ754BA3S2CMGJY4F')
ON CONFLICT DO NOTHING;

INSERT INTO restaurant_branches (id, restaurant_id, geography, label)
VALUES
(
  '01M4N5WPMTG65PA6B9BYVJWJVB',
  '01KZK4AW296W26ZR0JMYPW71S0',
  'SRID=4326;POINT(121.02152 14.55212)',
  'Greenbelt 3 Makati'
),
(
  '01M4N5Y20MTSHP4RVW8WM4E827',
  '01KZK4B0R1NKKGG2Y2E1NWCATK',
  'SRID=4326;POINT(120.98026 14.53173)',
  'S Maison Pasay'
)
ON CONFLICT (id) DO UPDATE
  SET
    restaurant_id = excluded.restaurant_id,
    geography = excluded.geography,
    label = excluded.label;
