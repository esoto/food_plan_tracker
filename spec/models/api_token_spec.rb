require "rails_helper"

RSpec.describe ApiToken, type: :model do
  describe "create" do
    it "generates a 64-char hex plaintext token, stored only as a SHA256 digest" do
      token = ApiToken.create!(name: "Test")

      expect(token.token).to match(/\A[0-9a-f]{64}\z/)
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(token.token))
      expect(token.token_digest).not_to eq(token.token)
    end

    it "honors a caller-supplied plaintext (for restoring an existing token)" do
      explicit = "a" * 64
      token = ApiToken.create!(name: "Imported", token: explicit)

      expect(token.token).to eq(explicit)
      expect(token.token_digest).to eq(Digest::SHA256.hexdigest(explicit))
    end

    it "requires a name and rejects duplicates" do
      ApiToken.create!(name: "MCP")
      dup = ApiToken.new(name: "MCP")
      expect(dup).not_to be_valid
      expect(dup.errors[:name]).to include("has already been taken")
    end
  end

  describe ".authenticate" do
    let!(:token) { ApiToken.create!(name: "MCP") }

    it "returns the token when the provided plaintext matches the digest" do
      expect(ApiToken.authenticate(token.token)).to eq(token)
    end

    it "returns nil for a wrong plaintext" do
      expect(ApiToken.authenticate("wrong")).to be_nil
    end

    it "returns nil for blank input (defends against empty-token bypass)" do
      expect(ApiToken.authenticate("")).to be_nil
      expect(ApiToken.authenticate(nil)).to be_nil
    end
  end

  describe "#touch_used!" do
    it "updates last_used_at and updated_at" do
      now = Time.zone.parse("2026-04-25 12:00:00")
      token = ApiToken.create!(name: "MCP")
      expect(token.last_used_at).to be_nil

      travel_to(now) { token.touch_used! }
      token.reload

      expect(token.last_used_at).to eq(now)
      expect(token.updated_at).to eq(now)
    end

    it "bypasses validations (the bypass is what makes this safe to call on every request)" do
      token = ApiToken.create!(name: "MCP")
      token.name = nil # would block save! via uniqueness/presence validations

      expect { token.touch_used! }.not_to raise_error
      token.reload
      expect(token.last_used_at).to be_present
    end

    it "throttles writes to once per ApiToken::TOUCH_INTERVAL" do
      token = ApiToken.create!(name: "MCP")
      first = Time.zone.parse("2026-04-25 12:00:00")
      travel_to(first) { token.touch_used! }
      token.reload

      # 30s later: no write (still inside the throttle window)
      travel_to(first + 30.seconds) { token.touch_used! }
      expect(token.reload.last_used_at).to eq(first)

      # 90s later: writes (window has passed)
      travel_to(first + 90.seconds) { token.touch_used! }
      expect(token.reload.last_used_at).to eq(first + 90.seconds)
    end
  end

  describe "#inspect" do
    it "redacts the token plaintext (defense against accidental log/inspect leakage)" do
      token = ApiToken.create!(name: "MCP")

      expect(token.token).to match(/\A[0-9a-f]{64}\z/)
      expect(token.inspect).to include("[FILTERED]")
      expect(token.inspect).not_to include(token.token)
    end
  end

  describe "#serializable_hash / to_json" do
    it "omits the token plaintext (defense against accidental render json:)" do
      token = ApiToken.create!(name: "MCP")

      expect(token.token).to match(/\A[0-9a-f]{64}\z/)
      expect(token.serializable_hash.keys).not_to include("token")
      expect(token.to_json).not_to include(token.token)
    end
  end
end
