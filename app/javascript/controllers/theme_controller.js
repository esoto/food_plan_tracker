import { Controller } from "@hotwired/stimulus"

// Persist theme in localStorage and apply the `dark` class on <html>
// so Tailwind's @custom-variant dark picks it up.
export default class extends Controller {
  connect() {
    this.apply(this.storedTheme)
  }

  toggle() {
    const next = this.storedTheme === "dark" ? "light" : "dark"
    localStorage.setItem("theme", next)
    this.apply(next)
  }

  apply(theme) {
    document.documentElement.classList.toggle("dark", theme === "dark")
  }

  get storedTheme() {
    return localStorage.getItem("theme") ||
      (window.matchMedia("(prefers-color-scheme: dark)").matches ? "dark" : "light")
  }
}
