require "rails_helper"

RSpec.describe "AccessRequests", type: :request do
  describe "GET /access_requests/new" do
    it "renders the request form" do
      get new_access_request_path
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Request access")
    end

    it "redirects authenticated users to root" do
      sign_in_as
      get new_access_request_path
      expect(response).to redirect_to(root_path)
    end
  end

  describe "POST /access_requests" do
    let(:valid_params) { { access_request: { email_address: "newcomer@example.com", message: "Please" } } }

    it "persists a fresh request and redirects with the generic notice" do
      expect { post access_requests_path, params: valid_params }
        .to change(AccessRequest, :count).by(1)
      expect(response).to redirect_to(new_session_path)
      expect(flash[:notice]).to eq(AccessRequestsController::SUBMITTED_NOTICE)
    end

    it "normalizes the email before storing" do
      post access_requests_path, params: { access_request: { email_address: "  MixedCase@Example.COM " } }
      expect(AccessRequest.last.email_address).to eq("mixedcase@example.com")
    end

    # The load-bearing contract: fresh / duplicate / already-a-user must be
    # byte-identical (status, location, flash) so an attacker can't probe which
    # addresses are registered. If any branch diverges, this fails.
    describe "enumeration safety" do
      def response_tuple
        [ response.status, response.headers["Location"], flash[:notice] ]
      end

      it "responds identically for fresh, duplicate, and existing-user emails" do
        post access_requests_path, params: { access_request: { email_address: "fresh@example.com" } }
        fresh = response_tuple

        AccessRequest.create!(email_address: "dup@example.com")
        post access_requests_path, params: { access_request: { email_address: "dup@example.com" } }
        duplicate = response_tuple

        create(:user, email_address: "member@example.com")
        post access_requests_path, params: { access_request: { email_address: "member@example.com" } }
        existing_user = response_tuple

        expect(duplicate).to eq(fresh)
        expect(existing_user).to eq(fresh)
      end

      it "does not create a request row for an address that already belongs to a user" do
        create(:user, email_address: "member@example.com")
        expect { post access_requests_path, params: { access_request: { email_address: "member@example.com" } } }
          .not_to change(AccessRequest, :count)
      end

      it "does not create a second row for a duplicate request" do
        AccessRequest.create!(email_address: "dup@example.com")
        expect { post access_requests_path, params: { access_request: { email_address: "dup@example.com" } } }
          .not_to change(AccessRequest, :count)
      end
    end

    describe "syntactic errors re-render (these are safe to surface)" do
      it "rejects a malformed email with 422" do
        post access_requests_path, params: { access_request: { email_address: "not-an-email" } }
        expect(response).to have_http_status(:unprocessable_entity)
        expect(response.body).to include("prohibited this request")
      end

      it "rejects an over-long message with 422" do
        post access_requests_path, params: { access_request: { email_address: "ok@example.com", message: "x" * 501 } }
        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    describe "rate limiting" do
      # rate_limit captures config.action_controller.cache_store at class-load
      # (:null_store in test, whose #increment returns nil and never trips).
      # Stub the store's counter so the limiter's `count > to` branch — and the
      # controller's `with:` handler (redirect + "Try again later.") — actually
      # runs. Fails if `to:` is raised past 5 or the handler changes.
      it "blocks once the submission count exceeds the limit of 5" do
        count = 0
        allow(AccessRequestsController.cache_store)
          .to receive(:increment) { count += 1 }

        6.times do |i|
          post access_requests_path, params: { access_request: { email_address: "rl#{i}@example.com" } }
        end

        expect(response).to redirect_to(new_access_request_path)
        expect(flash[:alert]).to eq("Try again later.")
      end
    end
  end

  describe "legacy registration URL" do
    it "redirects /registration/new to the access-request form" do
      get "/registration/new"
      expect(response).to redirect_to("/access_requests/new")
    end
  end
end
