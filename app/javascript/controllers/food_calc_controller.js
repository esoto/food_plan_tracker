import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = {
    servingGrams: Number,
    kcal: Number,
    protein: Number,
    carbs: Number,
    fat: Number
  }

  static targets = ["serving", "kcal", "protein", "carbs", "fat", "quantityInput"]

  connect() {
    this.multiplier = 1.0
  }

  setMultiplier(event) {
    this.multiplier = parseFloat(event.currentTarget.dataset.multiplier)
    this.element.querySelectorAll("[data-multiplier]").forEach(btn => {
      btn.dataset.active = String(parseFloat(btn.dataset.multiplier) === this.multiplier)
    })
    const m = this.multiplier
    this.servingTarget.textContent = Math.round(this.servingGramsValue * m)
    this.kcalTarget.textContent = Math.round(this.kcalValue * m)
    this.proteinTarget.textContent = (this.proteinValue * m).toFixed(0)
    this.carbsTarget.textContent = (this.carbsValue * m).toFixed(0)
    this.fatTarget.textContent = (this.fatValue * m).toFixed(0)
    if (this.hasQuantityInputTarget) {
      this.quantityInputTarget.value = (this.servingGramsValue * m).toFixed(2)
    }
  }
}
