# frozen_string_literal: true

# When the Next.js dev server rewrites /api/backend/* to http://127.0.0.1:3001, Rack sees
# Host: 127.0.0.1:3001. Session cookies are then scoped to 127.0.0.1, but the user visits
# http://localhost:3000 — a different host — so the browser never sends the cookie on the
# next request. Prefer X-Forwarded-Host (set by Next middleware) so Set-Cookie matches the
# browser origin.
class ForwardedHost
  def initialize(app)
    @app = app
  end

  def call(env)
    raw = env["HTTP_X_FORWARDED_HOST"].presence
    if raw
      env["HTTP_HOST"] = raw.split(",").first.strip
    end
    @app.call(env)
  end
end
