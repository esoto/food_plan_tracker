require "rails_helper"

RSpec.describe GoalsController, type: :request do
  let(:goal) { create(:goal, user: Current.user) }

  before { sign_in_as }

  describe "PATCH /goals/:id" do
    context "with valid params" do
      it "updates the goal and redirects with 303 See Other" do
        patch goal_path(goal), params: { goal: { target_value: 18.5 } }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(settings_path)
        expect(goal.reload.target_value.to_f).to eq(18.5)
      end

      it "sets a success notice" do
        patch goal_path(goal), params: { goal: { target_value: 18.5 } }
        expect(flash[:notice]).to include(goal.display_name)
      end
    end

    context "with invalid params" do
      it "redirects with 303 See Other and an alert" do
        patch goal_path(goal), params: { goal: { target_value: nil } }

        expect(response).to have_http_status(:see_other)
        expect(response).to redirect_to(settings_path)
        expect(flash[:alert]).to be_present
      end
    end
  end

  describe "cross-tenant isolation" do
    let(:user_b) { create(:user) }

    it "PATCH another user's goal returns 404 and does not mutate it" do
      b = create(:goal, user: user_b, target_value: 19.0)
      patch goal_path(b), params: { goal: { target_value: 99 } }

      expect(response).to have_http_status(:not_found)
      # Load-bearing: even if a future change adds a rescue_from that turns
      # RecordNotFound into a 200, the foreign record must not be mutated.
      expect(b.reload.target_value.to_f).to eq(19.0)
    end
  end
end
