class InvitationsMailer < ApplicationMailer
  def invite(user)
    @user = user
    @invitation_url = edit_invitation_url(user.generate_token_for(:invitation))
    mail subject: "You're invited to Food Plan Tracker", to: user.email_address
  end
end
