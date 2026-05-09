# ADR 0008: Prospect invite flow — WaitlistEntry → Account + User

## Status

Accepted (2026-05-09)

## Context

The waitlist landing page collects `email`, `full_name`, and `company_name` from **Prospects** (people interested in Toaster who do not yet have an account). Admins need a way to convert a Prospect into a live `Account` + `User` without leaving the Toaster admin UI and without sending temporary passwords over email.

Two alternatives were considered for the admin→prospect handoff:

- **Prospect-first (self-serve):** Admin clicks invite; prospect lands on a page and self-provisions account name, password, etc. Rejected — conflicts with the no-anonymous-self-signup principle in ADR 0007, and adds ambiguity about who controls the account name.
- **Admin-first with temp password:** Admin creates account and user, sets a temporary password, emails it to the prospect. Rejected — temp credentials in email are a security smell and require the prospect to do an extra password-change step.

## Decision

### Prospect data collected at signup

`WaitlistEntry` stores `email`, `full_name`, and `company_name`. These are the only fields collected — they have direct functional destinations (pre-fill the invite form) and anything else belongs in a CRM, not Toaster's DB.

### WaitlistEntry status lifecycle

A `WaitlistEntry` carries a `status` enum:

| Status | Meaning |
|---|---|
| `pending` | Signed up, not yet invited |
| `invited` | Admin sent invite; Devise reset link delivered; awaiting first login |
| `converted` | Prospect completed password setup and signed in |
| `expired` | Devise reset token expired before prospect clicked the link |

Transitions:
- `pending → invited` — admin submits `/admin/waitlist/:id/invite`
- `invited → converted` — detected automatically via Devise after-sign-in callback (matches on email, `sign_in_count == 1`)
- `invited → expired` — detected via background job or on next admin view load (checks `reset_password_sent_at` against Devise's token TTL)
- `expired → invited` — admin re-invites; new Devise token generated, status reset to `invited`

### Invite form (`/admin/waitlist/:id/invite`)

Pre-filled from the `WaitlistEntry`:

| Field | Source | Editable |
|---|---|---|
| Account name | `company_name` | Yes |
| User full name | `full_name` | Yes |
| User email | `email` | Yes |
| User role | hardcoded `venue_manager` | No |

One submit creates `Account` + `User` (no usable password), generates a Devise password reset token, sends the invite email ("your account is ready — click here to set your password"), and marks `invited_at` + `status: :invited` on the `WaitlistEntry`. All in a single transaction — partial state is not permitted.

### Invite email

Sent via Resend (`WaitlistMailer` or a new `InviteMailer`). Contains a Devise password reset link. No temporary password is included. The prospect sets their own credentials on first visit.

### Conversion detection

A Devise `after_sign_in` callback on `User` checks for a `WaitlistEntry` with matching email in `invited` status and marks it `converted`. This fires automatically — no admin action required.

### Admin account for admins

All admin users belong to the **"Toaster" account** (seeded in production, id stable). Admins are never created via the invite flow — they are provisioned directly by other admins via `/admin/users/new`.

## Consequences

- `WaitlistEntry` gains `full_name`, `company_name`, `status` (enum), `invited_at` columns via migration.
- Landing page waitlist form gains two new fields (full name, company name).
- New route: `GET/POST /admin/waitlist` (list) and `GET/POST /admin/waitlist/:id/invite`.
- Devise after-sign-in callback added to `User` for conversion detection.
- Background job (or lazy check) needed to detect `invited → expired` transitions.
- `WaitlistMailer` gains an `invite` action (or new `InviteMailer` is created).
