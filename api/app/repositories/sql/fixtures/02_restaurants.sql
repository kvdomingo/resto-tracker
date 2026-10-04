INSERT INTO restaurants (
  id, created_by_id, name, price_tier, tags, branches, instagram_handle,
  website, menu_url, is_reservation_required
)
VALUES (
  '01KZK4AW296W26ZR0JMYPW71S0', 'system', 'Cafe Breton', 2, ARRAY['french', 'pastries'],
  ARRAY[
    ROW('Greenbelt 3 Makati', 'SRID=4326;POINT(121.02152 14.55212)')
  ]::RESTAURANT_BRANCH[],
  'cafebretonph',
  NULL, NULL, FALSE
),
(
  '01KZK4B0R1NKKGG2Y2E1NWCATK', 'system', 'Mamou', 3, ARRAY['steak', 'italian'],
  ARRAY[
    ROW('S Maison Pasay', 'SRID=4326;POINT(120.98026 14.53173)')
  ]::RESTAURANT_BRANCH[],
  'mymamou',
  NULL, NULL, FALSE
)
ON CONFLICT (id) DO UPDATE
  SET
    name = excluded.name,
    price_tier = excluded.price_tier,
    tags = excluded.tags,
    branches = excluded.branches,
    instagram_handle = excluded.instagram_handle,
    website = excluded.website,
    menu_url = excluded.menu_url,
    is_reservation_required = excluded.is_reservation_required;
