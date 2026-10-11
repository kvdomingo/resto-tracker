## Purpose

Defines the shared restaurant catalogue: what a restaurant is (its name, price
tier, branches, tags, and optional links), how signed-in users add and maintain
the restaurants they created, how anyone browses the catalogue on a map, and how
users review restaurants.

## ADDED Requirements

### Requirement: Restaurant shape

A restaurant SHALL have a name, a price tier from 1 to 5, at least one branch,
and at least one tag. A restaurant MAY additionally have a website URL, a menu
URL, an Instagram handle, and a flag saying reservations are required, which
defaults to false. Every restaurant SHALL record the user who created it; if
that user is deleted, the restaurant remains with no recorded creator.

#### Scenario: Restaurant with only required fields

- **WHEN** a user submits a restaurant with a name, a price tier, one branch,
  and one tag, and no optional fields
- **THEN** the restaurant is created with reservations not required

#### Scenario: Restaurant with all optional fields

- **WHEN** a user submits a restaurant that also carries a website URL, a menu
  URL, an Instagram handle, and reservations required
- **THEN** all four are stored and shown on the restaurant's detail view

#### Scenario: Optional fields left blank

- **WHEN** a user submits a restaurant leaving an optional field empty
- **THEN** that field is stored as absent, not as an empty string, and no broken
  link is rendered

### Requirement: Restaurant validation

The system SHALL reject a restaurant whose name is empty or longer than 200
characters, whose price tier is outside 1–5, that has no branches, that has no
tags, or whose supplied URLs are not valid `http` or `https` URLs.

#### Scenario: Missing name

- **WHEN** a user submits a restaurant with a blank or whitespace-only name
- **THEN** the system responds `422 Unprocessable Entity` identifying the name
  field and creates nothing

#### Scenario: Price tier out of range

- **WHEN** a user submits a price tier of 0 or 6
- **THEN** the system responds `422 Unprocessable Entity` identifying the price
  tier field

#### Scenario: No branches

- **WHEN** a user submits a restaurant with an empty branch list
- **THEN** the system responds `422 Unprocessable Entity` identifying the
  branches field

#### Scenario: No tags

- **WHEN** a user submits a restaurant with an empty tag list
- **THEN** the system responds `422 Unprocessable Entity` identifying the tags
  field

#### Scenario: Malformed URL

- **WHEN** a user submits `not-a-url` or a `javascript:` URL as the website or
  menu link
- **THEN** the system responds `422 Unprocessable Entity` identifying that field

### Requirement: Restaurant branches

Each branch SHALL carry a human-friendly label (for example "SM Megamall" or
"Poblacion branch") and an exact map point as a latitude and longitude. A
restaurant MAY have several branches.

#### Scenario: Branch captured from a map

- **WHEN** a user drops a pin on the map and types a label for it
- **THEN** the branch is stored with that label and the pin's latitude and
  longitude
- **AND** reopening the restaurant shows the pin in the same place

#### Scenario: Multiple branches

- **WHEN** a user adds three branches to one restaurant
- **THEN** all three are stored against that restaurant and all three render as
  pins on its detail map

#### Scenario: Branch without a label

- **WHEN** a user submits a branch with coordinates but a blank label
- **THEN** the system responds `422 Unprocessable Entity` identifying that
  branch's label

#### Scenario: Coordinates out of range

- **WHEN** a user submits a latitude outside −90..90 or a longitude outside
  −180..180
- **THEN** the system responds `422 Unprocessable Entity` identifying the
  offending coordinate

#### Scenario: Editing branches

- **WHEN** the creator edits a restaurant, removing one branch and adding
  another
- **THEN** the resulting restaurant has exactly the branches submitted

### Requirement: Restaurant tags

Tags SHALL be short free-form labels shared across the whole catalogue. The
system SHALL trim surrounding whitespace, SHALL treat tags that differ only in
letter case as the same tag, and SHALL attach each distinct tag to a restaurant
only once.

#### Scenario: Duplicate tags collapse

- **WHEN** a user submits the tags `Ramen`, `ramen`, and ` ramen `
- **THEN** the restaurant carries a single `ramen` tag

#### Scenario: Tag reuse across restaurants

- **WHEN** two users tag different restaurants `ramen` and `Ramen`
- **THEN** both restaurants carry the same tag, and filtering by it returns both

#### Scenario: Overlong tag

- **WHEN** a user submits a tag longer than 50 characters
- **THEN** the system responds `422 Unprocessable Entity` identifying the tags
  field

#### Scenario: Tag list

- **WHEN** anyone requests the available tags
- **THEN** the system returns every tag in the catalogue, for use as filter
  choices and suggestions

### Requirement: Create, edit, and delete restaurants

A signed-in user SHALL be able to create a restaurant. Its creator SHALL be able
to edit and delete it. Deleting a restaurant SHALL also remove its branches, tag
associations, reviews, and every user's personal-list status for it.

#### Scenario: Create

- **WHEN** a signed-in user submits a valid new restaurant with its branches and
  tags
- **THEN** the system stores the restaurant, branches, and tags together, or
  none of them
- **AND** responds `201 Created` with the stored restaurant including its
  identifier
- **AND** the user is recorded as its creator

#### Scenario: Edit

- **WHEN** the creator submits changes to their restaurant
- **THEN** the stored restaurant reflects exactly the submitted values,
  including cleared optional fields

#### Scenario: Delete

- **WHEN** the creator deletes their restaurant
- **THEN** the system responds `204 No Content`
- **AND** the restaurant, its branches, tag associations, reviews, and list
  statuses are gone from subsequent reads

#### Scenario: Restaurant does not exist

- **WHEN** a signed-in user reads, edits, or deletes an identifier that matches
  no restaurant
- **THEN** the system responds `404 Not Found`

### Requirement: Read a restaurant

Reading a restaurant SHALL return its name, price tier, its branches with labels
and coordinates, its tags, whichever optional fields are set, and its average
rating and review count. For a signed-in reader, it SHALL also return that
reader's personal-list status for the restaurant, if any.

#### Scenario: Detail view

- **WHEN** anyone opens a restaurant
- **THEN** the response carries the name, price tier, all branches with labels
  and coordinates, all tags, the set optional fields, and the rating summary

#### Scenario: Detail view while signed in

- **WHEN** a signed-in user who marked a restaurant `tried` opens it
- **THEN** the response also carries the status `tried`

### Requirement: Browse restaurants by map area

The system SHALL list restaurants that have at least one branch inside a
requested map bounding box (north, east, south, west), paginated, with each
entry carrying its branches and their coordinates so they can be drawn as pins.
The list SHALL accept an optional free-text search over restaurant names and
branch labels, and an optional tag filter. Filters SHALL combine as AND.

#### Scenario: Restaurants in view

- **WHEN** anyone requests restaurants for a bounding box
- **THEN** only restaurants with a branch inside that box are returned, each
  with its branches

#### Scenario: Map moves

- **WHEN** a user pans or zooms the map
- **THEN** the list is refreshed for the new visible area and the area is kept
  in the URL so a refresh or shared link shows the same view

#### Scenario: Invalid bounding box

- **WHEN** a request supplies a latitude outside −90..90 or a longitude outside
  −180..180 for the box
- **THEN** the system responds `422 Unprocessable Entity`

#### Scenario: Pagination

- **WHEN** a request asks for a page size above 100
- **THEN** the system responds `422 Unprocessable Entity`

#### Scenario: Search within the area

- **WHEN** a user searches for `mega` while viewing an area
- **THEN** restaurants in the area whose name or any branch label contains
  `mega`, case-insensitively, are returned

#### Scenario: Nothing in the area

- **WHEN** no restaurants match the area and filters
- **THEN** the system responds with an empty collection and the UI says nothing
  was found in this area

### Requirement: Reviews

A signed-in user SHALL be able to review a restaurant with a rating from 1 to 5
and non-empty text, optionally posted anonymously. Reviews SHALL be readable by
anyone. A user SHALL be able to edit and delete only their own reviews.

#### Scenario: Write a review

- **WHEN** a signed-in user submits a rating of 4 and some text for a restaurant
- **THEN** the review is stored with that user as its author and appears on the
  restaurant's detail view

#### Scenario: Anonymous review

- **WHEN** a user posts a review marked anonymous
- **THEN** other readers see the rating and text but not the author

#### Scenario: Invalid review

- **WHEN** a user submits a rating outside 1–5 or empty text
- **THEN** the system responds `422 Unprocessable Entity` identifying the field

#### Scenario: Someone else's review

- **WHEN** a signed-in user tries to edit or delete a review written by another
  user
- **THEN** the system responds `403 Forbidden` and the review is unchanged

#### Scenario: Rating summary

- **WHEN** a restaurant has reviews rated 3, 4, and 5
- **THEN** its list entry and detail view show an average of 4 from 3 reviews
