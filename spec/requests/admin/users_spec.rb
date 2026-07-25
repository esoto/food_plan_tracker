require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  include ActiveJob::TestHelper

  around do |example|
    previous_adapter = ActiveJob::Base.queue_adapter
    ActiveJob::Base.queue_adapter = :test
    example.run
  ensure
    ActiveJob::Base.queue_adapter = previous_adapter
  end

  let(:admin) { create(:user, :admin) }

  describe "authorization" do
    let(:member) { create(:user) }
    let(:target) { create(:user) }
    let!(:access_request) { create(:access_request) }

    # Route helper symbols (not procs) so they resolve in the example's own
    # binding via `send` — a proc created at group-definition time captures
    # the wrong `self` and can't see `target`/`member` (instance-only lets).
    ROUTE_HELPERS = [
      [ :get,    :admin_users_path,                  false ],
      [ :get,    :new_admin_user_path,                false ],
      [ :post,   :admin_users_path,                   false ],
      [ :patch,  :deactivate_admin_user_path,          true ],
      [ :patch,  :reactivate_admin_user_path,          true ],
      [ :patch,  :promote_admin_user_path,              true ],
      [ :patch,  :demote_admin_user_path,               true ],
      [ :post,   :send_password_reset_admin_user_path,  true ],
      [ :post,   :resend_invite_admin_user_path,         true ],
      [ :delete, :admin_user_path,                       true ]
    ].freeze

    ROUTE_HELPERS.each do |verb, helper, needs_target|
      it "404s for a signed-in member on #{verb.upcase} #{helper}" do
        sign_in_as(member)
        path = needs_target ? send(helper, target) : send(helper)
        send(verb, path)
        expect(response).to have_http_status(:not_found)
      end

      it "redirects an anonymous visitor to login on #{verb.upcase} #{helper}" do
        path = needs_target ? send(helper, target) : send(helper)
        send(verb, path)
        expect(response).to redirect_to(new_session_path)
      end
    end

    it "404s for a member hitting access_requests#approve" do
      sign_in_as(member)
      post approve_admin_access_request_path(access_request)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects an anonymous visitor on access_requests#approve" do
      post approve_admin_access_request_path(access_request)
      expect(response).to redirect_to(new_session_path)
    end

    it "404s for a member hitting access_requests#destroy" do
      sign_in_as(member)
      delete admin_access_request_path(access_request)
      expect(response).to have_http_status(:not_found)
    end

    it "redirects an anonymous visitor on access_requests#destroy" do
      delete admin_access_request_path(access_request)
      expect(response).to redirect_to(new_session_path)
    end
  end

  describe "GET /admin (index)" do
    it "shows insights per user, including the never-active case" do
      sign_in_as(admin)

      active_user = create(:user, email_address: "active@example.com")
      plan = create(:plan, user: active_user)
      create(:daily_log, user: active_user, plan: plan, date: "2026-01-01")
      create(:daily_log, user: active_user, plan: plan, date: "2026-01-02")
      create(:api_token, user: active_user, last_used_at: 2.days.ago)
      create(:push_subscription, user: active_user)
      active_user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1")

      quiet_user = create(:user, email_address: "quiet@example.com")

      get admin_root_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("active@example.com")
      expect(response.body).to include("quiet@example.com")
      expect(response.body).to include("2 days · 1 tokens · 1 push")
      expect(response.body).to include("0 days · 0 tokens · 0 push")
      expect(response.body).to include("never")
    end

    it "reflects the greater of session vs. api_token activity" do
      sign_in_as(admin)

      newer_token_user = create(:user, email_address: "newer-token@example.com")
      newer_token_user.sessions.create!(user_agent: "test", ip_address: "127.0.0.1", updated_at: 10.days.ago)
      create(:api_token, user: newer_token_user, last_used_at: 1.hour.ago)

      get admin_root_path

      expect(response.body).to include("newer-token@example.com")
      expect(response.body).not_to include("10 days")
    end

    it "lists pending access requests" do
      sign_in_as(admin)
      request = create(:access_request, email_address: "wants-in@example.com", message: "let me in please")

      get admin_root_path

      expect(response.body).to include("wants-in@example.com")
      expect(response.body).to include("let me in please")
    end
  end

  describe "POST /admin/users (create)" do
    it "invites a new user with the selected role, never rendering a password" do
      sign_in_as(admin)

      expect {
        perform_enqueued_jobs do
          post admin_users_path, params: { user: { email_address: "new-admin@example.com", role: "admin" } }
        end
      }.to change(User, :count).by(1)

      user = User.find_by(email_address: "new-admin@example.com")
      expect(user).to be_admin
      expect(response).to redirect_to(admin_root_path)
      expect(response.body).not_to match(/password/i)

      expect(ActionMailer::Base.deliveries.last.to).to eq([ "new-admin@example.com" ])
    end

    it "enqueues the invitation mail" do
      sign_in_as(admin)

      expect {
        post admin_users_path, params: { user: { email_address: "queued@example.com", role: "member" } }
      }.to have_enqueued_mail(InvitationsMailer, :invite)
    end

    it "re-renders with 422 for an invalid email" do
      sign_in_as(admin)

      post admin_users_path, params: { user: { email_address: "not-an-email", role: "member" } }

      expect(response).to have_http_status(:unprocessable_entity)
    end

    # role is assigned explicitly (not mass-assigned) and validated against the
    # enum, so a tampered/unknown role param falls back to member rather than
    # raising or setting an unexpected value. Fails if create reverts to
    # mass-assigning :role or drops the requested_role allowlist.
    it "defaults an unknown role param to member" do
      sign_in_as(admin)

      post admin_users_path, params: { user: { email_address: "tampered@example.com", role: "superadmin" } }

      expect(User.find_by(email_address: "tampered@example.com")).to be_member
    end
  end

  describe "state-changing member actions" do
    it "deactivates and reactivates" do
      sign_in_as(admin)
      target = create(:user)

      patch deactivate_admin_user_path(target)
      expect(response).to redirect_to(admin_root_path)
      expect(target.reload).to be_deactivated

      patch reactivate_admin_user_path(target)
      expect(response).to redirect_to(admin_root_path)
      expect(target.reload).not_to be_deactivated
    end

    it "promotes and demotes" do
      sign_in_as(admin)
      create(:user, :admin) # second admin so demote below is not the last one
      target = create(:user)

      patch promote_admin_user_path(target)
      expect(target.reload).to be_admin

      patch demote_admin_user_path(target)
      expect(target.reload).to be_member
    end

    it "destroys the user" do
      sign_in_as(admin)
      target = create(:user)

      expect { delete admin_user_path(target) }.to change(User, :count).by(-1)
      expect(response).to redirect_to(admin_root_path)
    end
  end

  describe "forbid_self" do
    it "refuses to destroy the acting admin's own account" do
      sign_in_as(admin)

      expect { delete admin_user_path(admin) }.not_to change(User, :count)
      expect(response).to redirect_to(admin_root_path)
      expect(flash[:alert]).to eq("You can't do that to your own account.")
    end

    it "refuses to deactivate the acting admin's own account" do
      sign_in_as(admin)

      patch deactivate_admin_user_path(admin)
      expect(admin.reload).not_to be_deactivated
      expect(flash[:alert]).to eq("You can't do that to your own account.")
    end

    it "refuses to demote the acting admin's own account" do
      sign_in_as(admin)
      create(:user, :admin)

      patch demote_admin_user_path(admin)
      expect(admin.reload).to be_admin
      expect(flash[:alert]).to eq("You can't do that to your own account.")
    end
  end

  # NOTE: `User#last_active_admin?` (the model guard behind rescue_from) can
  # only be true for a record that is itself the sole active admin. Reaching
  # the controller at all requires Current.user to be an active admin
  # (require_admin), so whenever the *sole* active admin is the request's
  # target, that target is necessarily Current.user — i.e. self. `forbid_self`
  # intercepts destroy/deactivate/demote on self before the model guard ever
  # runs, which means rescue_from(User::LastAdminError) is unreachable via
  # these three controller actions in any state this controller can produce.
  # The guard itself is exercised directly at the model layer in
  # spec/models/user_spec.rb (#deactivate!, #demote!, #destroy "raises for
  # the last active admin"). Here we only confirm the two-or-more-admins
  # happy path, and that acting on the sole admin is blocked end-to-end
  # (via forbid_self, since that's what's actually reachable).
  describe "last-admin protection (end-to-end, reachable only via forbid_self)" do
    it "blocks demoting/deactivating/destroying the sole admin (self)" do
      sign_in_as(admin)

      patch demote_admin_user_path(admin)
      expect(admin.reload).to be_admin

      patch deactivate_admin_user_path(admin)
      expect(admin.reload).not_to be_deactivated

      expect { delete admin_user_path(admin) }.not_to change(User, :count)
    end

    it "allows demoting/deactivating/destroying a non-self admin when a second admin exists" do
      sign_in_as(admin)
      other_admin = create(:user, :admin)

      patch demote_admin_user_path(other_admin)
      expect(other_admin.reload).to be_member

      other_admin.update!(role: :admin)
      patch deactivate_admin_user_path(other_admin)
      expect(other_admin.reload).to be_deactivated

      other_admin.update!(deactivated_at: nil)
      expect { delete admin_user_path(other_admin) }.to change(User, :count).by(-1)
    end
  end

  describe "destroy cleans up Doorkeeper grants/tokens" do
    it "removes the user's access tokens" do
      sign_in_as(admin)
      target = create(:user)
      application = Doorkeeper::Application.create!(name: "Test Client", redirect_uri: "https://example.com/cb", scopes: "mcp", confidential: true)
      Doorkeeper::AccessToken.create!(application: application, resource_owner_id: target.id, scopes: "mcp")

      expect {
        delete admin_user_path(target)
      }.to change { Doorkeeper::AccessToken.where(resource_owner_id: target.id).count }.from(1).to(0)
    end
  end

  describe "send_password_reset / resend_invite" do
    it "enqueues a password reset mail" do
      sign_in_as(admin)
      target = create(:user)

      expect {
        post send_password_reset_admin_user_path(target)
      }.to have_enqueued_mail(PasswordsMailer, :reset)

      expect(response).to redirect_to(admin_root_path)
    end

    it "enqueues an invitation mail on resend" do
      sign_in_as(admin)
      target = create(:user)

      expect {
        post resend_invite_admin_user_path(target)
      }.to have_enqueued_mail(InvitationsMailer, :invite)

      expect(response).to redirect_to(admin_root_path)
    end
  end
end
