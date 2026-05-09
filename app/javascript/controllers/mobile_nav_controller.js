import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["drawer", "overlay"]

  toggle() {
    const open = this.drawerTarget.classList.toggle("sidebar-drawer--open")
    this.overlayTarget.classList.toggle("sidebar-overlay--visible", open)
    document.body.classList.toggle("nav-open", open)
  }

  close() {
    this.drawerTarget.classList.remove("sidebar-drawer--open")
    this.overlayTarget.classList.remove("sidebar-overlay--visible")
    document.body.classList.remove("nav-open")
  }
}
