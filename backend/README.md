# Backend

## Mission Control for Solid Queue

Mission Control is mounted at `/jobs` (for example `http://127.0.0.1:3001/jobs` when Rails listens on port 3001) and provides queue/job visibility plus retry/discard controls for Solid Queue. Authentication for Mission Control is HTTP Basic when enabled—not the same as app `/auth/login`.

- `development` / `test`: HTTP basic auth is disabled for faster local iteration and specs.
- Non-development environments (for example `staging`, `production`): HTTP basic auth is required.

Set these environment variables outside development/test:

- `MISSION_CONTROL_USERNAME` (optional, defaults to `ops`)
- `MISSION_CONTROL_PASSWORD` (required)
