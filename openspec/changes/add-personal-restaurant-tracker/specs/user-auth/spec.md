## Purpose

Establishes who is using the app: sign-in handled by an external identity
provider, a local user record that authored content points at, and the rules for
what an anonymous visitor, a signed-in user, and a restaurant's creator may each
do.

## ADDED Requirements

### Requirement: Sign-in via external identity provider

The system SHALL authenticate users through an external identity provider's
OAuth flow, brokered by the backend. The system SHALL NOT store passwords,
password hashes, or any other primary credential.

#### Scenario: Starting sign-in

- **WHEN** a visitor chooses to sign in
- **THEN** the system sends them to the identity provider's sign-in page

#### Scenario: New user signs in for the first time

- **WHEN** a person completes the identity provider's sign-in flow and the app
  has no local record for the returned provider user ID
- **THEN** the system creates a local user record holding that provider user
  ID, the email address reported by the provider, and their display name if the
  provider reports one
- **AND** the person is signed in and redirected to the app

#### Scenario: Returning user signs in

- **WHEN** a person completes sign-in and a local user record already exists for
  the returned provider user ID
- **THEN** the system reuses that record without creating a duplicate

#### Scenario: Concurrent first sign-in

- **WHEN** two sign-in completions for the same new provider user ID arrive at
  the same time
- **THEN** exactly one local user record exists afterwards and both sign-ins
  succeed

#### Scenario: Sign-in is abandoned or fails

- **WHEN** the identity provider reports a failed or cancelled sign-in
- **THEN** no local user record is created
- **AND** the person is returned to the app with a message explaining sign-in
  did not complete

### Requirement: Session handling

After sign-in, the system SHALL hold the provider's session in a signed,
HTTP-only cookie, and SHALL verify that session with the identity provider
before treating a request as authenticated.

#### Scenario: Request with a valid session

- **WHEN** a request arrives with a session the provider confirms is valid
- **THEN** the request is processed as the local user mapped to that provider
  user ID

#### Scenario: Request with no session

- **WHEN** a request arrives with no session
- **THEN** the request is processed as an anonymous visitor
- **AND** an endpoint that requires sign-in responds `401 Unauthorized` and
  performs no read or write

#### Scenario: Request with an expired or revoked session

- **WHEN** a request arrives with a session the provider rejects
- **THEN** the system clears the session cookie and processes the request as an
  anonymous visitor

#### Scenario: Identity provider is unreachable

- **WHEN** session verification cannot reach the identity provider
- **THEN** an endpoint that requires sign-in responds `503 Service Unavailable`
- **AND** the session cookie is kept, so the person is still signed in once the
  provider recovers

#### Scenario: Current user

- **WHEN** a signed-in user asks who they are
- **THEN** the system returns their local user record
- **AND** the same request from an anonymous visitor responds
  `401 Unauthorized`

### Requirement: Sign-out

The system SHALL let a signed-in user end their session.

#### Scenario: User signs out

- **WHEN** a signed-in user chooses to sign out
- **THEN** the session is revoked at the identity provider and the session
  cookie is cleared
- **AND** the person is redirected to the app as an anonymous visitor

### Requirement: Access rules

Browsing the restaurant catalogue SHALL NOT require sign-in. Creating content
SHALL require sign-in. Editing or deleting a restaurant SHALL be allowed only to
the user who created it. A user's personal list SHALL be readable and writable
only by that user.

#### Scenario: Anonymous browsing

- **WHEN** an anonymous visitor lists restaurants or opens one
- **THEN** the system responds with the catalogue data

#### Scenario: Anonymous write

- **WHEN** an anonymous visitor tries to create a restaurant, change a list
  status, or write a review
- **THEN** the system responds `401 Unauthorized` and stores nothing

#### Scenario: Non-creator edits or deletes a restaurant

- **WHEN** a signed-in user submits an edit or delete for a restaurant created by
  a different user
- **THEN** the system responds `403 Forbidden` and the restaurant is unchanged

#### Scenario: Another user's personal list

- **WHEN** a signed-in user requests their personal list
- **THEN** the response contains only their own statuses, never another user's
