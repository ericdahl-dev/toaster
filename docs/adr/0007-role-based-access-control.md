# ADR 0007: Role-based access control with admin and venue_manager roles

## Status

Accepted (2026-05-09)

## Context

All authenticated users in Toaster were previously equivalent — no role distinction, no admin-only surfaces. Two problems emerged:

1. **No way to provision accounts or users through the UI.** New tenants could only be created via seeds or the Rails console, which is not viable as onboarding scales.
2. **`/jobs` (GoodJob dashboard) was unprotected.** Any authenticated user — or anyone who could reach the server — could inspect and retry background jobs.

Toaster is invite-only; there is no self-service sign-up. An admin must provision each new account and its initial user. This maps cleanly to a two-role model rather than a full permission matrix.

## Decision

Add a `role` integer enum to `User` with two values: `venue_manager` (default, 0) and `admin` (1). Use Pundit as the authorization library.

**Admin capabilities:**
- Access the `/jobs` GoodJob dashboard
- Create new `Account` records with an initial `venue_manager` user (`/admin/accounts/new`)
- Add `venue_manager` users to existing accounts (`/admin/users/new`)

**Venue manager capabilities:**
- Everything accessible today (booking requests, drafts, inbox threads, mail connections, venues)
- No access to admin routes — redirected with a flash message

**`/jobs` protection:** The GoodJob engine is mounted inside a Devise `authenticate` constraint that requires `admin?`. Authenticated non-admins hitting `/jobs` are redirected to root rather than receiving a 404.

**Authorization layer:** `Admin::BaseController` enforces `require_admin!` via `before_action`. `ApplicationController` rescues `Pundit::NotAuthorizedError` globally and redirects to root with a flash.

## Consequences

- Existing users receive `venue_manager` role (DB default); the dev seed user and the production bootstrap user are explicitly set to `admin`.
- Admin-gated controllers live under the `Admin::` namespace and inherit `Admin::BaseController`.
- Fine-grained per-venue scoping (e.g. a user can only see venues they manage) is out of scope for now — all venue managers within an account share the same access.
- Email-based invitation flow (magic links, Devise Invitable) is out of scope — admins set a temporary password at creation time.
