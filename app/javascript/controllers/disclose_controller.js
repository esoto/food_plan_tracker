import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["panel"]

  toggle(event) {
    event.preventDefault()
    if (this.hasPanelTarget) {
      this.panelTarget.classList.toggle("hidden")
      const expanded = !this.panelTarget.classList.contains("hidden")
      event.currentTarget.setAttribute("aria-expanded", String(expanded))
    }
  }
}
