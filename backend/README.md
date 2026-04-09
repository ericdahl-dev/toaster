# Backend

## Mission Control for Solid Queue

Mission Control is mounted at `/jobs` and provides queue/job visibility plus retry/discard controls for Solid Queue.

- `development` / `test`: HTTP basic auth is disabled for faster local iteration and specs.
- non-development/test environments (for example `staging`, `production`): HTTP basic auth is required.

Set these environment variables in non-development/test environments:

- `MISSION_CONTROL_USERNAME` (optional, defaults to `ops`)
- `MISSION_CONTROL_PASSWORD` (required)
