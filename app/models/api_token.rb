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

  TOUCH_INTERVAL = 1.minute

  validates :name, presence: true, uniqueness: true
  validates :token_digest, presence: true, uniqueness: true

  before_validation :set_digest, on: :create

  def self.authenticate(provided)
    return nil if provided.blank?
    digest = Digest::SHA256.hexdigest(provided)
    candidate = find_by(token_digest: digest)
    # Constant-time compare across hit vs miss. The find_by index lookup
    # itself is not constant-time (B-tree miss is slightly faster than hit),
    # so we always perform a fixed-size compare against either the row's
    # digest or a 64-char zero string. Network jitter dominates either way,
    # but matching the previous secure_compare hardening is free.
    reference = candidate&.token_digest || ("0" * 64)
    if candidate && ActiveSupport::SecurityUtils.secure_compare(digest, reference)
      candidate
    end
  end

  # Bumps last_used_at for operator visibility. Called on every authenticated
  # API request, so we throttle to once per TOUCH_INTERVAL to avoid SQLite
  # write contention on bursty MCP clients (the hot row's UPDATE serializes
  # against every other writer in the same SQLite file).
  def touch_used!
    return if last_used_at && last_used_at > TOUCH_INTERVAL.ago
    update_columns(last_used_at: Time.current, updated_at: Time.current)
  end

  # Defense-in-depth: keep `token` plaintext out of inspect / JSON / log
  # streams even on the in-memory record returned from .create. Rails'
  # filter_parameters does NOT cover attr_accessor-backed virtual attributes.
  def inspect
    masked = token.present? ? "[FILTERED]" : nil
    "#<ApiToken id=#{id.inspect} name=#{name.inspect} token=#{masked.inspect}>"
  end

  def serializable_hash(options = nil)
    super(options).except("token")
  end

  private

  def set_digest
    @token ||= SecureRandom.hex(32)
    self.token_digest = Digest::SHA256.hexdigest(@token)
  end
end
