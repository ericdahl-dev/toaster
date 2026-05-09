import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["container", "template"]

  addRow(event) {
    event.preventDefault()
    const content = this.templateTarget.innerHTML.replace(
      /NEW_RECORD/g,
      new Date().getTime()
    )
    this.containerTarget.insertAdjacentHTML("beforeend", content)
  }

  removeRow(event) {
    event.preventDefault()
    const row = event.target.closest("[data-nested-form-target='row']")
    if (row) {
      const destroyField = row.querySelector("input[name*='_destroy']")
      if (destroyField) {
        destroyField.value = "1"
        row.style.display = "none"
      } else {
        row.remove()
      }
    }
  }
}
