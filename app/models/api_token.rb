require "digest"
require "securerandom"

# Bearer token for the JSON API. Plaintext is generated on create, hashed
# (SHA-256, 256 bits of entropy from openssl rand -hex 32 — bcrypt is unnecessary
# at this entropy and would prevent indexed lookups), and never stored.
#
# Lifecycle:
#   t = ApiToken.create!(name: "MCP")
#   t.token        # plaintext, only available right after create — store it now
#   ApiToken.authenticate(plaintext) # → ApiToken or nil
#
# To revoke: ApiToken.find_by(name: "MCP").destroy
class ApiToken < ApplicationRecord
  attr_accessor :token

  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :set_digest, on: :create

  def self.authenticate(provided)
    return nil if provided.blank?
    digest = Digest::SHA256.hexdigest(provided)
    find_by(token_digest: digest)
  end

  def touch_used!
    update_columns(last_used_at: Time.current, updated_at: Time.current)
  end

  private

  def set_digest
    @token ||= SecureRandom.hex(32)
    self.token_digest = Digest::SHA256.hexdigest(@token)
  end
end
