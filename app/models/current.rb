class Current < ActiveSupport::CurrentAttributes
  attribute :session

  # Supports both assignment patterns:
  #   Current.session = Session.find(id)  → user derived from session
  #   Current.user  = user                → explicit assignment (API/MCP)
  #
  # The explicit value takes precedence so that code paths that create a
  # synthetic Session (e.g. API token auth) can set the user directly
  # without needing a persisted Session row.
  def user
    @user || session&.user
  end

  def user=(user)
    @user = user
  end

  resets { @user = nil }
end
