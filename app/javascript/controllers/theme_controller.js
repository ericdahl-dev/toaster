import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "toaster-theme"

/* DM Mono lacks many Unicode symbols; use SVG + currentColor. */
const SUN_SVG =
  '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><circle cx="12" cy="12" r="4"/><path d="M12 2v2M12 20v2M4.93 4.93l1.41 1.41M17.66 17.66l1.41 1.41M2 12h2M20 12h2M4.93 19.07l1.41-1.41M17.66 6.34l1.41-1.41"/></svg>'

const MOON_SVG =
  '<svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>'

export default class extends Controller {
  static targets = ["icon"]

  connect() {
    this._renderIcon()
  }

  toggle(event) {
    event.preventDefault()
    const cur = document.documentElement.getAttribute("data-theme") || "dark"
    const next = cur === "light" ? "dark" : "light"
    document.documentElement.setAttribute("data-theme", next)
    try {
      localStorage.setItem(STORAGE_KEY, next)
    } catch (_) {
      /* ignore private mode / quota */
    }
    this._renderIcon()
  }

  _renderIcon() {
    if (!this.hasIconTarget) return
    const t = document.documentElement.getAttribute("data-theme") || "dark"
    const html = t === "light" ? MOON_SVG : SUN_SVG
    const label = t === "light" ? "Switch to dark mode" : "Switch to light mode"
    this.iconTargets.forEach((el) => {
      el.innerHTML = html
      const btn = el.closest("button")
      if (btn) btn.setAttribute("aria-label", label)
    })
  }
}
