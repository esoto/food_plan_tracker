import { Controller } from "@hotwired/stimulus"

// Generic show/hide controller for cases where the trigger and panel
// can't be expressed as a <summary>-first <details> tree (e.g. when the
// trigger sits inline next to sibling content and the panel must appear
// elsewhere in the DOM). For top-level card disclosures where summary
// semantics fit naturally, prefer native <details>/<summary> (see the
// "Why this stack?" pattern in app/views/supplements/show.html.erb).
//
// The trigger should provide aria-expanded plus aria-label and (optional)
// title attributes ending in "Show ..." / "Hide ..." — the controller
// flips those on every toggle so screen readers and tooltips stay in sync.
export default class extends Controller {
  static targets = ["panel"]

  toggle(event) {
    event.preventDefault()
    if (!this.hasPanelTarget) return

    this.panelTarget.classList.toggle("hidden")
    const expanded = !this.panelTarget.classList.contains("hidden")
    const trigger = event.currentTarget
    trigger.setAttribute("aria-expanded", String(expanded))

    const verb = expanded ? "Hide" : "Show"
    const swapVerb = (value) => value && value.replace(/^(Show|Hide)\b/, verb)
    const nextLabel = swapVerb(trigger.getAttribute("aria-label"))
    if (nextLabel) trigger.setAttribute("aria-label", nextLabel)
    const nextTitle = swapVerb(trigger.getAttribute("title"))
    if (nextTitle) trigger.setAttribute("title", nextTitle)
  }
}
