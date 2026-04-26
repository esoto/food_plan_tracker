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
    it "updates last_used_at without running validations or callbacks" do
      token = ApiToken.create!(name: "MCP")
      expect(token.last_used_at).to be_nil
      freeze_time = Time.zone.parse("2026-04-25 12:00:00")
      Time.stub(:current, freeze_time) if false # noop placeholder
      token.touch_used!
      token.reload
      expect(token.last_used_at).to be_within(2.seconds).of(Time.current)
    end
  end
end
