## Purpose

Establishes who is using the app: sign-in handled by an external identity
provider, and a local user record that every owned resource points at so that
one person's restaurants stay theirs.

## ADDED Requirements

### Requirement: Sign-in via external identity provider

The system SHALL authenticate users through an external identity provider. The
system SHALL NOT store passwords, password hashes, or any other primary
credential.

#### Scenario: New user signs in for the first time

- **WHEN** a person completes the identity provider's sign-in flow and the app
  has no local record for the returned provider user ID
- **THEN** the system creates a local user record holding that provider user ID
  and the email address reported by the provider
- **AND** the person is signed in and lands on their (empty) restaurant list

#### Scenario: Returning user signs in

- **WHEN** a person completes sign-in and a local user record already exists for
  the returned provider user ID
- **THEN** the system reuses that record without creating a duplicate
- **AND** the person sees the restaurants they previously added

#### Scenario: Sign-in is abandoned or fails

- **WHEN** the identity provider reports a failed or cancelled sign-in
- **THEN** no local user record is created
- **AND** the person is returned to the sign-in screen with a message explaining
  sign-in did not complete

### Requirement: Request authentication

Every API request that reads or writes user-owned data SHALL carry a session
credential issued by the identity provider, and the system SHALL verify that
credential with the provider before acting on the request.

#### Scenario: Request with a valid session

- **WHEN** a request arrives with a session credential the provider confirms is
  valid
- **THEN** the request is processed as the local user mapped to that provider
  user ID

#### Scenario: Request with a missing session

- **WHEN** a request to a protected endpoint arrives with no session credential
- **THEN** the system responds `401 Unauthorized` and performs no read or write

#### Scenario: Request with an expired or revoked session

- **WHEN** a request arrives with a session credential the provider rejects
- **THEN** the system responds `401 Unauthorized`
- **AND** the frontend clears local session state and redirects the person to
  sign-in

#### Scenario: Identity provider is unreachable

- **WHEN** session verification cannot reach the identity provider
- **THEN** the system responds `503 Service Unavailable` and does not treat the
  request as authenticated

### Requirement: Sign-out

The system SHALL let a signed-in user end their session.

#### Scenario: User signs out

- **WHEN** a signed-in user chooses to sign out
- **THEN** the session is revoked at the identity provider and cleared from the
  browser
- **AND** subsequent requests using that credential are rejected with
  `401 Unauthorized`

### Requirement: Ownership isolation

Data owned by one user SHALL NOT be readable or writable by another user.

#### Scenario: User requests another user's restaurant

- **WHEN** a signed-in user requests a restaurant owned by a different user, by
  its identifier
- **THEN** the system responds `404 Not Found`, disclosing nothing about whether
  that identifier exists

#### Scenario: User modifies another user's restaurant

- **WHEN** a signed-in user submits an update or delete for a restaurant owned
  by a different user
- **THEN** the system responds `404 Not Found` and the target record is
  unchanged
