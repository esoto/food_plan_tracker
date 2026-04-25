require "rails_helper"

RSpec.describe PlansController, type: :request do
  let(:plan) { create(:plan) }

  before { sign_in_as }

  describe "PATCH /plans/:id" do
    context "with valid params" do
      it "updates the plan and redirects with 303 See Other" do
        patch plan_path(plan), params: { plan: { target_kcal: 2200 } }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(settings_path)
        expect(plan.reload.target_kcal).to eq(2200)
      end

      it "sets a success notice" do
        patch plan_path(plan), params: { plan: { target_kcal: 2200 } }
        expect(flash[:notice]).to include(plan.name)
      end
    end

    context "with invalid params" do
      it "redirects with 303 See Other and an alert" do
        patch plan_path(plan), params: { plan: { target_kcal: 0 } }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end

      it "does not update the plan" do
        original_kcal = plan.target_kcal
        patch plan_path(plan), params: { plan: { target_kcal: 0 } }
        expect(plan.reload.target_kcal).to eq(original_kcal)
      end
    end
  end
end
