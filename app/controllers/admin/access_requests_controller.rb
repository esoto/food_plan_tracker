module Admin
  class AccessRequestsController < Admin::BaseController
    before_action :set_access_request

    def approve
      user = nil

      ApplicationRecord.transaction do
        user = User.create!(email_address: @access_request.email_address, password: SecureRandom.alphanumeric(24))
        @access_request.destroy!
      end

      InvitationsMailer.invite(user).deliver_later
      redirect_to admin_root_path, notice: "Invited #{user.email_address}."
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      @access_request.destroy
      redirect_to admin_root_path, alert: "#{@access_request.email_address} already has an account."
    end

    def destroy
      @access_request.destroy
      redirect_to admin_root_path, notice: "Request dismissed."
    end

    private

    def set_access_request
      @access_request = AccessRequest.find(params[:id])
    end
  end
end
