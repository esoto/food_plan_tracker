# frozen_string_literal: true

# Include with `it_behaves_like "food-gated page"` inside a request-spec
# describe block that already signs a user in (via sign_in_as) and defines
# `let(:make_request)` as a proc that performs the representative request
# for that controller, e.g.:
#
#   it_behaves_like "food-gated page" do
#     let(:make_request) { -> { get menu_path } }
#   end
RSpec.shared_examples "food-gated page" do
  it "redirects to root with an alert when the user's food tracking is off" do
    Current.user.update!(food_tracking_enabled: false)

    make_request.call

    expect(response).to redirect_to(root_path)
    expect(flash[:alert]).to eq("Food tracking is not enabled for your account.")
  end

  it "does not block the request when the user's food tracking is on" do
    Current.user.update!(food_tracking_enabled: true)

    make_request.call

    # Some gated actions redirect to root on success too (e.g. logging a
    # food onto today), so assert on the gate's alert copy rather than the
    # redirect target.
    expect(flash[:alert]).not_to eq("Food tracking is not enabled for your account.")
  end
end
