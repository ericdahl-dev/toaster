import { Controller } from "@hotwired/stimulus"

const STORAGE_KEY = "toaster-theme"

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
    const sym = t === "light" ? "☾" : "☀"
    const label = t === "light" ? "Switch to dark mode" : "Switch to light mode"
    this.iconTargets.forEach((el) => {
      el.textContent = sym
      el.setAttribute("aria-label", label)
    })
  }
}
