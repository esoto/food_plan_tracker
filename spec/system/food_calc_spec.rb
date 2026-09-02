require "rails_helper"

RSpec.describe "Food calculation", type: :system do
  describe "S4d: Multiplier changes update displayed nutrition" do
    it "2x multiplier updates kcal, protein, carbs, fat and hidden quantity input" do
      alice = create_onboarded_user(email: "alice@example.com")
      alice.update!(food_tracking_enabled: true)
      food = create(:food, name: "Chicken Breast", category: :protein, serving_grams: 100, kcal: 200, protein_g: 10.5, carbs_g: 25.0, fat_g: 5.0)

      system_sign_in(email: "alice@example.com", password: "password12345")

      visit exchanges_path(q: "Chicken")

      # Initial state: 1x multiplier active
      expect(page).to have_text("100g")
      expect(page).to have_text("200 kcal")
      expect(page).to have_text("10g P") # view renders protein_g.to_i (10.5 -> 10)
      expect(page).to have_text("25g C")
      expect(page).to have_text("5g F")

      # Click 2x button
      find("[data-multiplier='2.0']").click

      # Assert multiplied values display
      expect(page).to have_text("200g")
      expect(page).to have_text("400 kcal")
      expect(page).to have_text("21g P")
      expect(page).to have_text("50g C")
      expect(page).to have_text("10g F")

      # Assert hidden quantity_grams input is updated
      quantity_input = find("[data-food-calc-target='quantityInput']", visible: false)
      expect(quantity_input.value).to eq "200.00"
    end
  end
end
