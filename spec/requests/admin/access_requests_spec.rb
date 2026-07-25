require "rails_helper"

RSpec.describe "Admin::AccessRequests", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  let(:admin) { create(:user, :admin) }

  describe "POST /admin/access_requests/:id/approve" do
    it "creates a user, destroys the request, and enqueues an invite" do
      sign_in_as(admin)
      access_request = create(:access_request, email_address: "approve-me@example.com")

      expect {
        expect {
          post approve_admin_access_request_path(access_request)
        }.to change(User, :count).by(1)
      }.to change(AccessRequest, :count).by(-1)

      expect(User.find_by(email_address: "approve-me@example.com")).to be_present
      expect(AccessRequest.exists?(access_request.id)).to be false
      expect(response).to redirect_to(admin_root_path)
      expect(flash[:notice]).to eq("Invited approve-me@example.com.")
    end

    it "enqueues the invitation mail" do
      sign_in_as(admin)
      access_request = create(:access_request, email_address: "queued-approve@example.com")

      expect {
        post approve_admin_access_request_path(access_request)
      }.to have_enqueued_mail(InvitationsMailer, :invite)
    end

    it "handles the race where a user with that email already exists" do
      sign_in_as(admin)
      create(:user, email_address: "already-here@example.com")
      access_request = create(:access_request, email_address: "already-here@example.com")

      expect {
        expect {
          post approve_admin_access_request_path(access_request)
        }.not_to change(User, :count)
      }.to change(AccessRequest, :count).by(-1)

      expect(response).to redirect_to(admin_root_path)
      expect(flash[:alert]).to eq("already-here@example.com already has an account.")
      expect(ActionMailer::Base.deliveries).to be_empty
    end
  end

  describe "DELETE /admin/access_requests/:id (deny)" do
    it "destroys the request" do
      sign_in_as(admin)
      access_request = create(:access_request)

      expect {
        delete admin_access_request_path(access_request)
      }.to change(AccessRequest, :count).by(-1)

      expect(response).to redirect_to(admin_root_path)
      expect(flash[:notice]).to eq("Request dismissed.")
    end
  end
end
