require "rails_helper"

RSpec.describe InvitationsMailer, type: :mailer do
  let(:user) { create(:user, email_address: "invitee@example.com") }

  describe "#invite" do
    subject(:mail) { described_class.invite(user) }

    it "addresses the invitee with the invitation subject" do
      expect(mail.to).to eq([ "invitee@example.com" ])
      expect(mail.subject).to eq("You're invited to Food Plan Tracker")
    end

    it "sends from the configured application sender" do
      expect(mail.from).to eq([ "no-reply@estebansoto.dev" ])
    end

    it "embeds a working invitation link whose token resolves to the user" do
      body = mail.body.encoded
      match = body.match(%r{/invitations/([^/"'\s]+)/edit})
      expect(match).to be_present, "expected an /invitations/:token/edit URL in the body"

      token = CGI.unescape(match[1])
      expect(User.find_by_token_for(:invitation, token)).to eq(user)
    end
  end
end
