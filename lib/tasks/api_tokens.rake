namespace :api_tokens do
  desc "Create a new API token (NAME=client-name) — prints the plaintext once, then it's gone forever"
  task create: :environment do
    name = ENV["NAME"].presence
    abort "Usage: bin/rails api_tokens:create NAME=client-name" unless name

    token = ApiToken.create!(name: name)
    puts "Created API token '#{token.name}'"
    puts "  Token (copy now — only shown once):"
    puts "    #{token.token}"
  end

  desc "List all API tokens with last-used timestamps"
  task list: :environment do
    unless ApiToken.exists?
      puts "(no API tokens — create one with bin/rails api_tokens:create NAME=...)"
      next
    end
    fmt = "%-25s %-22s %s"
    puts format(fmt, "name", "last_used_at", "created_at")
    puts "-" * 70
    ApiToken.order(:name).each do |t|
      last = t.last_used_at&.iso8601 || "(never)"
      puts format(fmt, t.name, last, t.created_at.iso8601)
    end
  end

  desc "Revoke an API token by name (NAME=client-name)"
  task revoke: :environment do
    name = ENV["NAME"].presence
    abort "Usage: bin/rails api_tokens:revoke NAME=client-name" unless name

    token = ApiToken.find_by(name: name)
    abort "No API token named '#{name}'" unless token
    token.destroy!
    puts "Revoked API token '#{name}'"
  end
end
