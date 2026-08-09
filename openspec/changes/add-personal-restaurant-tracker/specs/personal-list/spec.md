## Purpose

The user-facing point of the app: one list of the restaurants a person has
added, each marked as already tried or still want to try, with enough filtering
to answer "where should we eat".

## ADDED Requirements

### Requirement: Tried / want-to-try status

Every restaurant a user owns SHALL carry exactly one status: `tried` or
`want_to_try`. The status SHALL be set at creation and SHALL be changeable
afterwards.

#### Scenario: Status chosen at creation

- **WHEN** a user creates a restaurant and selects "want to try"
- **THEN** the restaurant is stored with status `want_to_try`

#### Scenario: Status defaults

- **WHEN** a user creates a restaurant without specifying a status
- **THEN** the restaurant is stored with status `want_to_try`

#### Scenario: Marking as tried

- **WHEN** a user changes a `want_to_try` restaurant to `tried`
- **THEN** the change is persisted and reflected the next time the list is
  loaded

#### Scenario: Invalid status

- **WHEN** a request supplies a status other than `tried` or `want_to_try`
- **THEN** the system responds `422 Unprocessable Entity` and the stored status
  is unchanged

### Requirement: Listing a user's restaurants

The system SHALL return the signed-in user's restaurants, and only theirs, with
each entry carrying enough detail to render a list row: name, status, tags,
first location label, and image URL if set.

#### Scenario: List returns only own restaurants

- **WHEN** a signed-in user requests their list while other users also have
  restaurants stored
- **THEN** the response contains exactly the restaurants that user owns

#### Scenario: Empty list

- **WHEN** a user with no restaurants requests their list
- **THEN** the system responds with an empty collection and the UI shows a
  prompt to add the first restaurant

#### Scenario: Default ordering

- **WHEN** a user requests their list without specifying an order
- **THEN** restaurants are returned most-recently-added first

### Requirement: Filtering the list

The system SHALL support filtering the list by status and by tag, and SHALL
support a free-text search over restaurant name and location labels. Filters
SHALL combine as AND.

#### Scenario: Filter by status

- **WHEN** a user filters by status `want_to_try`
- **THEN** only their `want_to_try` restaurants are returned

#### Scenario: Filter by tag

- **WHEN** a user filters by the tag `ramen`
- **THEN** only their restaurants carrying that tag are returned

#### Scenario: Combined filters

- **WHEN** a user filters by status `tried` and tag `ramen` together
- **THEN** only restaurants matching both are returned

#### Scenario: Free-text search

- **WHEN** a user searches for `mega`
- **THEN** restaurants whose name or any location label contains `mega`,
  case-insensitively, are returned

#### Scenario: Filters match nothing

- **WHEN** a user applies filters that match none of their restaurants
- **THEN** the system responds with an empty collection and the UI distinguishes
  "no matches" from "no restaurants yet"

### Requirement: Tag list for filtering

The system SHALL expose the distinct tags used across the signed-in user's own
restaurants so the UI can offer them as filter choices.

#### Scenario: Tags reflect current data

- **WHEN** a user removes the last restaurant carrying the tag `ramen`
- **THEN** `ramen` no longer appears among that user's available filter tags

#### Scenario: Tags are per-user

- **WHEN** a user requests their available tags
- **THEN** tags used only by other users' restaurants are absent from the
  response
