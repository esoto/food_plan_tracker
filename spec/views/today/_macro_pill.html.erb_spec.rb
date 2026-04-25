require "rails_helper"

RSpec.describe "today/_macro_pill.html.erb", type: :view do
  let(:base_locals) { { color: "rose", label: "Protein", unit: "g" } }

  context "when consumed is zero" do
    it "renders a starter dot instead of an invisible 0% fill" do
      render partial: "today/macro_pill", locals: base_locals.merge(consumed: 0, target: 180)
      expect(rendered).to have_css("span.bg-rose-300.rounded-full")
      expect(rendered).not_to have_css("div[style*='width: 0%']")
    end
  end

  context "when consumed is positive" do
    it "renders a proportional colored fill" do
      render partial: "today/macro_pill", locals: base_locals.merge(consumed: 90, target: 180)
      expect(rendered).to have_css("div.bg-rose-500[style*='width: 50%']")
      expect(rendered).not_to have_css("span.bg-rose-300")
    end

    it "clamps the fill to 100% when consumed exceeds target" do
      render partial: "today/macro_pill", locals: base_locals.merge(consumed: 250, target: 180)
      expect(rendered).to have_css("div.bg-rose-500[style*='width: 100%']")
    end
  end
end
