# Dark industrial design system for the operator dashboard

Toaster's operator dashboard is used by venue staff managing inbound booking requests — not by end customers. The audience is operational: people checking a queue, reviewing AI drafts, approving replies. The UI should feel like a tool, not a product.

The chosen aesthetic is dark industrial: near-black surfaces (`#0e0f0f`), monospaced typography throughout (DM Mono), amber accent (`#f59e0b`) derived from the product name, and a two-column shell (topbar + sidebar + main) that prioritises information density over visual softness. The login page uses a full-page layout with a subtle amber radial glow. Status indicators use coloured dot badges (amber=pending, green=confirmed/active, blue=reviewing, red=rejected/cancelled).

The Figtree typeface is used for headings and the logo wordmark to provide contrast against the monospaced data layer without introducing a third font family. (Syne was used initially and replaced by Figtree in May 2026 to consolidate the display typeface across the operator dashboard and the landing page — Figtree at weight 900 was already in use for the landing page hero.)

This direction was chosen because:
- Venue operators scan data constantly — monospaced tables align columns and make differences between rows instantly legible.
- Dark themes reduce eye strain during long sessions at a front desk or back-of-house terminal.
- The amber accent is on-brand (toast) and provides high contrast on dark surfaces without the overused purple-gradient aesthetic common in AI tooling.
- A clear visual identity makes the product memorable and signals it was designed for a specific purpose, not assembled from generic components.

## Considered options

- **Light Tailwind defaults (previous)** — fast to build, but generic slate-on-white with no clear identity. Dropped when the Next.js frontend was removed and the Rails views became the primary UI.
- **Light theme with custom identity** — possible but harder to achieve high density and legibility with the same type choices.
- **Dark industrial with DM Mono + Figtree + amber (chosen)** — distinctive, density-friendly, on-brand, and easy to extend consistently. Figtree replaced Syne in May 2026 to consolidate display typefaces.

## Constraints this decision imposes

- New views must use the CSS custom properties defined in `app/assets/stylesheets/application.css` (e.g. `var(--amber)`, `var(--surface)`, `var(--border)`). Do not introduce Tailwind utility classes for colours or typography — keep the design token layer in one place.
- Status badge classes follow the pattern `badge-{status}` where `{status}` matches the ActiveRecord model's status string directly.
- The `helper_method :current_user` declaration in `ApplicationController` is required for the layout's conditional nav rendering — do not remove it.
- Tailwind CSS is retained for layout utilities only (if needed); the design identity lives in `application.css`.
