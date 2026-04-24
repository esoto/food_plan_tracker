import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    servingGrams: Number,
    kcal: Number,
    protein: Number,
    carbs: Number,
    fat: Number
  }

  static targets = ["serving", "kcal", "protein", "carbs", "fat"]

  setMultiplier(event) {
    const mult = parseFloat(event.currentTarget.dataset.multiplier)
    this.element.querySelectorAll("[data-multiplier]").forEach(btn => {
      btn.dataset.active = String(parseFloat(btn.dataset.multiplier) === mult)
    })
    this.servingTarget.textContent = Math.round(this.servingGramsValue * mult)
    this.kcalTarget.textContent = Math.round(this.kcalValue * mult)
    this.proteinTarget.textContent = (this.proteinValue * mult).toFixed(0)
    this.carbsTarget.textContent = (this.carbsValue * mult).toFixed(0)
    this.fatTarget.textContent = (this.fatValue * mult).toFixed(0)
  }
}
