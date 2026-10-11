## Purpose

The user-facing point of the app: each person's own list of catalogue
restaurants, each marked as already tried or still want to try, with enough
filtering to answer "where should we eat".

## ADDED Requirements

### Requirement: Tried / want-to-try status

A signed-in user SHALL be able to put any catalogue restaurant on their personal
list with exactly one status, `tried` or `want_to_try`, change that status, and
remove the restaurant from their list. A status SHALL belong to one user and one
restaurant; other users' statuses for the same restaurant SHALL be unaffected.

#### Scenario: Adding to the list

- **WHEN** a user marks a restaurant "want to try"
- **THEN** the restaurant is on their list with status `want_to_try`

#### Scenario: Marking as tried

- **WHEN** a user changes a `want_to_try` restaurant to `tried`
- **THEN** the change is persisted and reflected the next time the list is
  loaded

#### Scenario: Statuses are per user

- **WHEN** one user marks a restaurant `tried` and another user has it as
  `want_to_try`
- **THEN** each user still sees their own status

#### Scenario: Removing from the list

- **WHEN** a user removes a restaurant from their list
- **THEN** it no longer appears on their list, and the restaurant itself stays in
  the catalogue

#### Scenario: Invalid status

- **WHEN** a request supplies a status other than `tried` or `want_to_try`
- **THEN** the system responds `422 Unprocessable Entity` and the stored status
  is unchanged

#### Scenario: Adding a restaurant you just created

- **WHEN** a user creates a restaurant and chooses a status in the same form
- **THEN** the restaurant is created and placed on their list with that status

### Requirement: Listing a user's restaurants

The system SHALL return the restaurants on the signed-in user's list, and only
their statuses, with each entry carrying enough detail to render a list row:
name, status, price tier, tags, and first branch label.

#### Scenario: List returns only own statuses

- **WHEN** a signed-in user requests their list while other users also have
  lists
- **THEN** the response contains exactly the restaurants on that user's list,
  with that user's statuses

#### Scenario: Empty list

- **WHEN** a user with nothing on their list requests it
- **THEN** the system responds with an empty collection and the UI prompts them
  to browse the map or add a restaurant

#### Scenario: Default ordering

- **WHEN** a user requests their list without specifying an order
- **THEN** restaurants are returned most-recently-added-to-the-list first

### Requirement: Filtering the list

The system SHALL support filtering the personal list by status and by tag, and
SHALL support a free-text search over restaurant name and branch labels. Filters
SHALL combine as AND.

#### Scenario: Filter by status

- **WHEN** a user filters by status `want_to_try`
- **THEN** only their `want_to_try` restaurants are returned

#### Scenario: Filter by tag

- **WHEN** a user filters by the tag `ramen`
- **THEN** only restaurants on their list carrying that tag are returned

#### Scenario: Combined filters

- **WHEN** a user filters by status `tried` and tag `ramen` together
- **THEN** only restaurants matching both are returned

#### Scenario: Free-text search

- **WHEN** a user searches for `mega`
- **THEN** restaurants on their list whose name or any branch label contains
  `mega`, case-insensitively, are returned

#### Scenario: Filters match nothing

- **WHEN** a user applies filters that match nothing on their list
- **THEN** the system responds with an empty collection and the UI distinguishes
  "no matches" from "nothing on your list yet"
