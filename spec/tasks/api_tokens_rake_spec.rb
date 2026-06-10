require "rails_helper"
require "rake"

RSpec.describe "api_tokens rake tasks" do
  before(:all) do
    Rake.application.rake_require("tasks/api_tokens", [Rails.root.join("lib").to_s])
    Rake::Task.define_task(:environment)
  end

  let!(:alice) { create(:user, email_address: "alice@example.com") }
  let!(:bob)   { create(:user, email_address: "bob@example.com") }

  def run_task(name, env)
    env.each { |k, v| ENV[k] = v }
    task = Rake::Task["api_tokens:#{name}"]
    task.reenable
    output = StringIO.new
    previous_stdout = $stdout
    $stdout = output
    task.invoke
    output.string
  ensure
    $stdout = previous_stdout
    env.each_key { |k| ENV.delete(k) }
  end

  describe "api_tokens:create" do
    it "creates a token owned by the named user (jobs/rake run with nil Current.user)" do
      expect(Current.user).to be_nil

      output = run_task("create", "NAME" => "MCP", "USER_EMAIL" => "alice@example.com")

      token = alice.api_tokens.find_by(name: "MCP")
      expect(token).to be_present
      expect(token.user).to eq(alice)
      expect(output).to include("for alice@example.com")
      expect(bob.api_tokens.count).to eq(0)
    end

    it "aborts without USER_EMAIL instead of crashing on a nil owner" do
      expect {
        run_task("create", "NAME" => "MCP")
      }.to raise_error(SystemExit)
      expect(ApiToken.count).to eq(0)
    end
  end

  describe "api_tokens:revoke" do
    it "revokes only the named user's token when names collide across users" do
      Current.set(user: alice) { ApiToken.create!(name: "MCP", user: alice) }
      Current.set(user: bob)   { ApiToken.create!(name: "MCP", user: bob) }

      run_task("revoke", "NAME" => "MCP", "USER_EMAIL" => "alice@example.com")

      expect(alice.api_tokens.where(name: "MCP")).to be_empty
      expect(bob.api_tokens.where(name: "MCP").count).to eq(1)
    end
  end

  describe "api_tokens:revoke with unknown user" do
    it "aborts on an email that matches no user" do
      expect {
        run_task("revoke", "NAME" => "X", "USER_EMAIL" => "ghost@example.com")
      }.to raise_error(SystemExit)
    end
  end

  describe "api_tokens:list" do
    it "filters to the named user's tokens when USER_EMAIL is given" do
      Current.set(user: alice) { ApiToken.create!(name: "AliceToken", user: alice) }
      Current.set(user: bob)   { ApiToken.create!(name: "BobToken", user: bob) }

      output = run_task("list", "USER_EMAIL" => "alice@example.com")

      expect(output).to include("AliceToken")
      expect(output).not_to include("BobToken")
    end
  end
end
