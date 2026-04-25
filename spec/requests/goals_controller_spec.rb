require "rails_helper"

RSpec.describe GoalsController, type: :request do
  let(:goal) { create(:goal) }

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
end
