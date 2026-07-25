class AccessRequestsController < ApplicationController
  allow_unauthenticated_access only: %i[new create]
  rate_limit to: 5, within: 1.hour, only: :create, with: -> { redirect_to new_access_request_path, alert: "Try again later." }

  # Shown for every non-syntactic outcome (fresh request, duplicate request,
  # or an email that already belongs to a user) so an attacker cannot probe
  # which addresses are registered by watching the response.
  SUBMITTED_NOTICE = "Thanks! If your request is approved you'll receive an email invitation."

  def new
    redirect_to root_path if authenticated?
    @access_request = AccessRequest.new
  end

  def create
    @access_request = AccessRequest.new(access_request_params)

    # An address that already belongs to a user must not create a request
    # row, but the response must be indistinguishable from a fresh submission.
    if User.exists?(email_address: @access_request.email_address)
      return redirect_to new_session_path, notice: SUBMITTED_NOTICE
    end

    @access_request.save!
    redirect_to new_session_path, notice: SUBMITTED_NOTICE
  rescue ActiveRecord::RecordInvalid
    # A duplicate request is enumeration-sensitive, so it must look like a
    # success. Only genuinely syntactic problems (bad format, over-long
    # message) re-render the form.
    if @access_request.errors.of_kind?(:email_address, :taken)
      redirect_to new_session_path, notice: SUBMITTED_NOTICE
    else
      render :new, status: :unprocessable_entity
    end
  rescue ActiveRecord::RecordNotUnique
    # Two concurrent submissions for the same address can both pass the
    # uniqueness validation; the DB index stops the loser here. Same
    # indistinguishable success response.
    redirect_to new_session_path, notice: SUBMITTED_NOTICE
  end

  private

  def access_request_params
    params.require(:access_request).permit(:email_address, :message)
  end
end
