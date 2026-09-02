require "rails_helper"

RSpec.describe User, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:sessions).dependent(:destroy) }
    it { is_expected.to have_many(:plans).dependent(:destroy) }
    it { is_expected.to have_many(:meals).dependent(:destroy) }
    it { is_expected.to have_many(:daily_logs).dependent(:destroy) }
    it { is_expected.to have_many(:supplements).dependent(:destroy) }
    it { is_expected.to have_many(:supplement_schedules).dependent(:destroy) }
    it { is_expected.to have_many(:goals).dependent(:destroy) }
    it { is_expected.to have_many(:biomarker_entries).dependent(:destroy) }
    it { is_expected.to have_many(:habits).dependent(:destroy) }
    it { is_expected.to have_many(:logged_foods).dependent(:destroy) }
    it { is_expected.to have_many(:api_tokens).dependent(:destroy) }
    it { is_expected.to have_many(:push_subscriptions).dependent(:destroy) }
    it { is_expected.to have_many(:reminder_preferences).dependent(:destroy) }
    it { is_expected.to have_many(:notification_deliveries).dependent(:destroy) }
    it { is_expected.to have_many(:meal_items).dependent(:destroy) }
  end

  describe "normalizations" do
    it "strips and downcases the email address" do
      user = create(:user, email_address: "  Hello@Example.COM  ")
      expect(user.email_address).to eq("hello@example.com")
    end
  end

  describe "role" do
    it "defaults to member" do
      expect(create(:user).role).to eq("member")
      expect(create(:user)).to be_member
    end

    it "supports the admin trait" do
      expect(create(:user, :admin)).to be_admin
    end
  end

  describe ".active" do
    it "excludes deactivated users" do
      active = create(:user)
      deactivated = create(:user, :deactivated)

      expect(User.active).to include(active)
      expect(User.active).not_to include(deactivated)
    end
  end

  describe "#deactivate!" do
    it "sets deactivated_at and destroys the user's sessions" do
      user = create(:user, :admin)
      create(:user, :admin) # keep another active admin so the guard allows it
      Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")

      expect { user.deactivate! }.to change { user.sessions.count }.from(1).to(0)
      expect(user.deactivated_at).to be_present
    end

    it "raises for the last active admin and leaves the record untouched" do
      user = create(:user, :admin)
      Session.create!(user: user, user_agent: "test", ip_address: "127.0.0.1")

      expect { user.deactivate! }.to raise_error(User::LastAdminError)

      expect(user.reload.deactivated_at).to be_nil
      expect(user.sessions.count).to eq(1)
    end

    it "succeeds when a second active admin exists" do
      user = create(:user, :admin)
      create(:user, :admin)

      expect { user.deactivate! }.not_to raise_error
      expect(user.reload.deactivated_at).to be_present
    end
  end

  describe "#reactivate!" do
    it "clears deactivated_at" do
      user = create(:user, :deactivated)

      user.reactivate!

      expect(user.reload.deactivated_at).to be_nil
    end
  end

  describe "#promote!" do
    it "makes the user an admin" do
      user = create(:user)

      user.promote!

      expect(user.reload).to be_admin
    end
  end

  describe "#demote!" do
    it "makes an admin a member when another active admin exists" do
      user = create(:user, :admin)
      create(:user, :admin)

      user.demote!

      expect(user.reload).to be_member
    end

    it "raises for the last active admin and leaves the role untouched" do
      user = create(:user, :admin)

      expect { user.demote! }.to raise_error(User::LastAdminError)
      expect(user.reload).to be_admin
    end
  end

  describe "#destroy" do
    it "raises for the last active admin" do
      user = create(:user, :admin)

      expect { user.destroy }.to raise_error(User::LastAdminError)
      expect(User.exists?(user.id)).to be(true)
    end

    it "destroys the user's doorkeeper grants and tokens" do
      user = create(:user)
      application = Doorkeeper::Application.create!(
        name: "Test Client", redirect_uri: "https://example.com/cb", scopes: "mcp", confidential: true
      )
      Doorkeeper::AccessToken.create!(application: application, resource_owner_id: user.id, scopes: "mcp")
      Doorkeeper::AccessGrant.create!(
        application: application, resource_owner_id: user.id,
        redirect_uri: "https://example.com/cb", expires_in: 600, token: "grant-token"
      )

      user.destroy

      expect(Doorkeeper::AccessToken.where(resource_owner_id: user.id).count).to eq(0)
      expect(Doorkeeper::AccessGrant.where(resource_owner_id: user.id).count).to eq(0)
    end

    it "nullifies foods the user created rather than deleting them" do
      user = create(:user)
      food = create(:food, created_by_user_id: user.id)

      user.destroy

      expect(Food.exists?(food.id)).to be(true)
      expect(food.reload.created_by_user_id).to be_nil
    end
  end

  describe "invitation token" do
    it "round-trips via find_by_token_for" do
      user = create(:user)
      token = user.generate_token_for(:invitation)

      expect(User.find_by_token_for(:invitation, token)).to eq(user)
    end

    it "expires after 3 days" do
      user = create(:user)
      token = user.generate_token_for(:invitation)

      travel_to(4.days.from_now) do
        expect(User.find_by_token_for(:invitation, token)).to be_nil
      end
    end

    it "becomes invalid after the user changes password" do
      user = create(:user)
      token = user.generate_token_for(:invitation)

      user.update!(password: "newpassword12345")

      expect(User.find_by_token_for(:invitation, token)).to be_nil
    end
  end

  describe ".with_admin_insights" do
    it "exposes per-user aggregates and the greatest activity timestamp" do
      logger = create(:user)
      plan = create(:plan, user: logger)
      create(:daily_log, user: logger, plan: plan, date: "2026-01-01")
      create(:daily_log, user: logger, plan: plan, date: "2026-01-02")
      create(:push_subscription, user: logger)
      # Session is the most-recent activity for this user.
      # update_column bypasses auto-timestamping, which would otherwise clobber updated_at.
      session_time = 2.days.ago
      Session.create!(user: logger, user_agent: "test", ip_address: "127.0.0.1").update_column(:updated_at, session_time)

      other = create(:user)
      # For `other`, an api_token used more recently than any session wins last_activity_at.
      token_time = 1.hour.ago
      create(:api_token, user: other, last_used_at: token_time)
      Session.create!(user: other, user_agent: "test", ip_address: "127.0.0.1").update_column(:updated_at, 5.days.ago)

      insights = User.with_admin_insights.index_by(&:id)

      logger_row = insights[logger.id]
      expect(logger_row.days_logged_count).to eq(2)
      expect(logger_row.push_subscriptions_count).to eq(1)
      expect(logger_row.api_tokens_count).to eq(0)
      expect(logger_row.last_activity_at).to be_within(1.second).of(session_time)

      other_row = insights[other.id]
      expect(other_row.api_tokens_count).to eq(1)
      expect(other_row.last_activity_at).to be_within(1.second).of(token_time)
    end
  end

  describe "food tracking flag" do
    it "defaults to disabled for new users" do
      expect(create(:user).food_tracking_enabled).to be(false)
    end

    it "enables and disables via the bang mutators" do
      user = create(:user)
      user.enable_food_tracking!
      expect(user.reload.food_tracking_enabled).to be(true)
      user.disable_food_tracking!
      expect(user.reload.food_tracking_enabled).to be(false)
    end
  end
end
