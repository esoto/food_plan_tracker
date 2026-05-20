require "rails_helper"

RSpec.describe Current, type: :model do
  describe "#user" do
    it "returns the explicit user when set directly" do
      user = create(:user)
      Current.user = user
      expect(Current.user).to eq(user)
    end

    it "delegates to session.user when no explicit user is set" do
      user = create(:user)
      session = Session.create!(user: user)
      Current.session = session
      expect(Current.user).to eq(user)
    end

    it "returns nil when neither explicit user nor session is set" do
      expect(Current.user).to be_nil
    end
  end

  describe "#user= precedence" do
    it "prefers the explicit user over session.user" do
      session_user = create(:user)
      explicit_user = create(:user)
      session = Session.create!(user: session_user)

      Current.session = session
      Current.user = explicit_user

      expect(Current.user).to eq(explicit_user)
    end
  end

  describe "reset hook" do
    it "clears the explicit user between resets" do
      user = create(:user)
      Current.user = user
      expect(Current.user).to eq(user)

      Current.reset
      expect(Current.user).to be_nil
    end
  end
end
