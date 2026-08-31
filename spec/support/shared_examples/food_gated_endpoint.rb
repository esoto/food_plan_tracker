# frozen_string_literal: true

# Include with `it_behaves_like "food-gated endpoint"` inside a request-spec
# describe block that already calls `stub_api_token` (so `Current.user` and
# `auth_headers` are available) and defines `let(:make_request)` as a proc
# that performs the representative request for that controller, e.g.:
#
#   it_behaves_like "food-gated endpoint" do
#     let(:make_request) { -> { get "/api/v1/today", headers: auth_headers } }
#   end
RSpec.shared_examples "food-gated endpoint" do
  it "returns 403 food_tracking_disabled when the user's food tracking is off" do
    Current.user.update!(food_tracking_enabled: false)

    make_request.call

    expect(response).to have_http_status(:forbidden)
    expect(response.parsed_body).to eq("error" => "food_tracking_disabled")
  end

  it "does not block the request when the user's food tracking is on" do
    Current.user.update!(food_tracking_enabled: true)

    make_request.call

    expect(response).not_to have_http_status(:forbidden)
  end
end
