class RegistrationsController < ApplicationController
  allow_unauthenticated_access only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Try again later." }

  def new
    redirect_to root_path if authenticated?
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    if @user.save
      Onboarding::SeedDefaults.call(@user)
      start_new_session_for @user
      redirect_to root_path, notice: "Welcome! Your account is ready."
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Two concurrent sign-ups for the same email can both pass the uniqueness
    # validation; the DB unique index stops the loser here. Render the same
    # 422 the validation would have produced instead of a 500.
    @user.errors.add(:email_address, "has already been taken")
    render :new, status: :unprocessable_entity
  end

  private

  def registration_params
    params.require(:user).permit(:email_address, :password, :password_confirmation)
  end
end
