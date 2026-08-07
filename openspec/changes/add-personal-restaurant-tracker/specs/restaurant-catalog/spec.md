## Purpose

Defines what a restaurant is in this app — the required name, locations, and tags, and the optional
image and links — and how a user creates, edits, and deletes the restaurants they own.

## ADDED Requirements

### Requirement: Restaurant shape

A restaurant SHALL have a name, at least one location, and at least one tag. A restaurant MAY
additionally have an image URL, a website URL, an Instagram URL, and a menu URL. Every restaurant
SHALL belong to exactly one owner.

#### Scenario: Restaurant with only required fields

- **WHEN** a user submits a restaurant with a name, one location, and one tag, and no optional
  fields
- **THEN** the restaurant is created and appears in that user's list

#### Scenario: Restaurant with all optional fields

- **WHEN** a user submits a restaurant that also carries an image URL, website URL, Instagram URL,
  and menu URL
- **THEN** all four are stored and shown on the restaurant's detail view as links

#### Scenario: Optional fields left blank

- **WHEN** a user submits a restaurant leaving an optional URL field empty
- **THEN** that field is stored as absent, not as an empty string, and no broken link is rendered

### Requirement: Restaurant validation

The system SHALL reject a restaurant whose name is empty or longer than 200 characters, that has no
locations, that has no tags, or whose supplied URLs are not valid `http` or `https` URLs.

#### Scenario: Missing name

- **WHEN** a user submits a restaurant with a blank or whitespace-only name
- **THEN** the system responds `422 Unprocessable Entity` identifying the name field and creates
  nothing

#### Scenario: No locations

- **WHEN** a user submits a restaurant with an empty location list
- **THEN** the system responds `422 Unprocessable Entity` identifying the locations field

#### Scenario: No tags

- **WHEN** a user submits a restaurant with an empty tag list
- **THEN** the system responds `422 Unprocessable Entity` identifying the tags field

#### Scenario: Malformed URL

- **WHEN** a user submits `not-a-url` or a `javascript:` URL as the website link
- **THEN** the system responds `422 Unprocessable Entity` identifying that field

### Requirement: Restaurant locations

Each location SHALL carry a human-friendly label (for example "SM Megamall" or "Poblacion branch")
and exact map coordinates as a latitude and longitude. A restaurant MAY have several locations, and
their order as submitted SHALL be preserved when the restaurant is read back.

#### Scenario: Location captured from a map

- **WHEN** a user drops a pin on the map and types a label for it
- **THEN** the location is stored with that label and the pin's latitude and longitude
- **AND** reopening the restaurant shows the pin in the same place

#### Scenario: Multiple branches

- **WHEN** a user adds three locations to one restaurant
- **THEN** all three are stored against that restaurant and all three render as pins on its detail
  map

#### Scenario: Location without a label

- **WHEN** a user submits a location with coordinates but a blank label
- **THEN** the system responds `422 Unprocessable Entity` identifying that location's label

#### Scenario: Coordinates out of range

- **WHEN** a user submits a latitude outside −90..90 or a longitude outside −180..180
- **THEN** the system responds `422 Unprocessable Entity` identifying the offending coordinate

#### Scenario: Editing locations

- **WHEN** a user edits a restaurant, removing one location and adding another
- **THEN** the resulting restaurant has exactly the locations submitted, in the submitted order

### Requirement: Restaurant tags

Tags SHALL be free-form short text labels chosen by the user. The system SHALL normalise tags by
trimming surrounding whitespace and lowercasing them, and SHALL store each distinct tag on a
restaurant only once.

#### Scenario: Duplicate tags collapse

- **WHEN** a user submits the tags `Ramen`, `ramen`, and ` ramen `
- **THEN** the restaurant ends up with the single tag `ramen`

#### Scenario: Tag reuse across restaurants

- **WHEN** a user tags two different restaurants `ramen`
- **THEN** both restaurants are returned when filtering that user's list by the tag `ramen`

#### Scenario: Overlong tag

- **WHEN** a user submits a tag longer than 50 characters
- **THEN** the system responds `422 Unprocessable Entity` identifying the tags field

### Requirement: Create, edit, and delete restaurants

A signed-in user SHALL be able to create a restaurant, edit any restaurant they own, and delete any
restaurant they own. Deleting a restaurant SHALL also remove its locations and tag associations.

#### Scenario: Create

- **WHEN** a signed-in user submits a valid new restaurant
- **THEN** the system responds `201 Created` with the stored restaurant including its identifier
- **AND** the user is recorded as its owner

#### Scenario: Edit

- **WHEN** a signed-in user submits changes to a restaurant they own
- **THEN** the stored restaurant reflects exactly the submitted values, including cleared optional
  fields

#### Scenario: Delete

- **WHEN** a signed-in user deletes a restaurant they own
- **THEN** the system responds `204 No Content`
- **AND** the restaurant, its locations, and its tag associations are gone from subsequent reads

#### Scenario: Delete something that does not exist

- **WHEN** a signed-in user deletes an identifier that matches no restaurant of theirs
- **THEN** the system responds `404 Not Found`

### Requirement: Read a restaurant

Reading a restaurant SHALL return its name, its locations with labels and coordinates, its tags,
whichever optional fields are set, and its personal-list status.

#### Scenario: Detail view

- **WHEN** a signed-in user opens a restaurant they own
- **THEN** the response carries the name, all locations with labels and coordinates, all tags, the
  set optional fields, and the tried / want-to-try status
