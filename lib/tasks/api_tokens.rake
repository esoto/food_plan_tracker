namespace :api_tokens do
  desc "Create a new API token (NAME=client-name USER_EMAIL=owner@example.com) — prints the plaintext once, then it's gone forever"
  task create: :environment do
    name  = ENV["NAME"].presence
    email = ENV["USER_EMAIL"].presence
    abort "Usage: bin/rails api_tokens:create NAME=client-name USER_EMAIL=owner@example.com" unless name && email

    user = User.find_by(email_address: email)
    abort "No user with email '#{email}'" unless user

    token = user.api_tokens.create!(name: name)
    puts "Created API token '#{token.name}' for #{user.email_address}"
    puts "  Token (copy now — only shown once):"
    puts "    #{token.token}"
  end

  desc "List API tokens with owners and last-used timestamps (optionally USER_EMAIL=owner@example.com)"
  task list: :environment do
    scope = ApiToken.all
    if (email = ENV["USER_EMAIL"].presence)
      user = User.find_by(email_address: email)
      abort "No user with email '#{email}'" unless user
      scope = user.api_tokens
    end

    unless scope.exists?
      puts "(no API tokens — create one with bin/rails api_tokens:create NAME=... USER_EMAIL=...)"
      next
    end
    fmt = "%-25s %-30s %-22s %s"
    puts format(fmt, "name", "owner", "last_used_at", "created_at")
    puts "-" * 100
    scope.includes(:user).order(:name).each do |t|
      last = t.last_used_at&.iso8601 || "(never)"
      puts format(fmt, t.name, t.user.email_address, last, t.created_at.iso8601)
    end
  end

  desc "Revoke an API token by name (NAME=client-name USER_EMAIL=owner@example.com)"
  task revoke: :environment do
    name  = ENV["NAME"].presence
    email = ENV["USER_EMAIL"].presence
    abort "Usage: bin/rails api_tokens:revoke NAME=client-name USER_EMAIL=owner@example.com" unless name && email

    user = User.find_by(email_address: email)
    abort "No user with email '#{email}'" unless user

    token = user.api_tokens.find_by(name: name)
    abort "No API token named '#{name}' for #{email}" unless token
    token.destroy!
    puts "Revoked API token '#{name}' for #{email}"
  end
end
