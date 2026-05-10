<wizard-report>
# PostHog post-wizard report

The wizard has completed a deep integration of PostHog analytics into this Ruby on Rails application. The `posthog-ruby` and `posthog-rails` gems were added to the Gemfile, a server-side initializer was configured at `config/initializers/posthog.rb` with auto-exception capture and ActiveJob instrumentation enabled, and the posthog-js snippet was added to the application layout for client-side tracking with automatic user identification. Ten business-critical events were instrumented across controllers and services covering the full user journey — from waitlist signup through venue setup and AI draft decisions.

| Event | Description | File |
|---|---|---|
| `waitlist_entry_submitted` | A visitor submitted their email and details to join the waitlist | `app/controllers/waitlist_entries_controller.rb` |
| `waitlist_converted` | A waitlisted user signed in for the first time, converting from invited to active | `app/services/waitlist_conversion_service.rb` |
| `user_signed_in` | A user successfully signed in — also used to identify the user in PostHog | `app/controllers/sessions_controller.rb` |
| `booking_request_status_changed` | A booking request transitioned between statuses (pending, reviewing, confirmed, rejected, cancelled) | `app/services/booking_requests/transition.rb` |
| `draft_approved` | A user approved an AI-generated draft reply and queued it for sending | `app/controllers/drafts_controller.rb` |
| `draft_rejected` | A user rejected an AI-generated draft reply | `app/controllers/drafts_controller.rb` |
| `mail_connection_created` | A user added a new IMAP mail connection to their account | `app/controllers/mail_connections_controller.rb` |
| `venue_created` | A user created a new venue | `app/controllers/venues_controller.rb` |
| `venue_document_uploaded` | A user uploaded a knowledge document for venue ingestion | `app/controllers/venue_documents_controller.rb` |
| `admin_account_created` | An admin created a new account and user in one transaction | `app/controllers/admin/accounts_controller.rb` |

## Next steps

We've built some insights and a dashboard for you to keep an eye on user behavior, based on the events we just instrumented:

- [Analytics basics dashboard](/dashboard/1564910)
- [Waitlist-to-Active Conversion Funnel](/insights/323aqiDL) — 3-step funnel: waitlist submit → converted → first sign-in
- [Booking Request Status Changes](/insights/OyCbKM4a) — daily volume of booking status transitions
- [Draft Approvals vs Rejections](/insights/q8kek85y) — AI draft quality signal
- [Daily Active Users (Sign-ins)](/insights/usCiGgUZ) — core engagement metric
- [Venue Setup Activity](/insights/gS48Gak1) — venue creation and document uploads

### Agent skill

We've left an agent skill folder in your project at `.claude/skills/integration-ruby-on-rails/`. You can use this context for further agent development when using Claude Code. This will help ensure the model provides the most up-to-date approaches for integrating PostHog.

</wizard-report>
