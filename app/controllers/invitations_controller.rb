class InvitationsController < ApplicationController
  allow_unauthenticated_access
  before_action :set_user_by_token

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      Onboarding::SeedDefaults.call(@user)
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome! Your account is ready."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def set_user_by_token
    @user = User.find_by_token_for!(:invitation, params[:token])

    # A deactivated account must never redeem an outstanding invitation; treat
    # its token as invalid so the same generic alert is shown.
    raise ActiveSupport::MessageVerifier::InvalidSignature if @user.deactivated?
  rescue ActiveSupport::MessageVerifier::InvalidSignature
    redirect_to new_session_path, alert: "Invitation link is invalid or has expired."
  end
end
