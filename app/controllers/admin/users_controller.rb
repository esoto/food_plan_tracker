module Admin
  class UsersController < Admin::BaseController
    before_action :set_user, except: %i[index new create]
    before_action :forbid_self, only: %i[destroy deactivate demote]

    # Defense-in-depth. The model raises LastAdminError to protect the last
    # active admin, but in practice forbid_self intercepts first: the only
    # record that can BE the sole active admin is Current.user (you must be an
    # active admin to reach here at all), and forbid_self already blocks
    # self-targeted destroy/deactivate/demote. This rescue is the safety net
    # for any future action that isn't covered by forbid_self. The invariant
    # itself is enforced and tested at the model level.
    rescue_from User::LastAdminError, with: :warn_last_admin

    def index
      @users = User.with_admin_insights
      @access_requests = AccessRequest.order(:created_at)
    end

    def new
      @user = User.new
    end

    def create
      @user = User.new(email_address: user_params[:email_address])
      @user.password = SecureRandom.alphanumeric(24)
      # Assign the privileged role attribute explicitly (never via mass
      # assignment) and only from the known enum keys, so a tampered param
      # can't set an unexpected value and defaults safely to member.
      @user.role = requested_role

      if @user.save
        InvitationsMailer.invite(@user).deliver_later
        redirect_to admin_root_path, notice: "Invited #{@user.email_address}."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      email = @user.email_address
      @user.destroy!
      redirect_to admin_root_path, notice: "Deleted #{email}."
    end

    def deactivate
      @user.deactivate!
      redirect_to admin_root_path, notice: "Deactivated #{@user.email_address}."
    end

    def reactivate
      @user.reactivate!
      redirect_to admin_root_path, notice: "Reactivated #{@user.email_address}."
    end

    def promote
      @user.promote!
      redirect_to admin_root_path, notice: "Promoted #{@user.email_address} to admin."
    end

    def demote
      @user.demote!
      redirect_to admin_root_path, notice: "Demoted #{@user.email_address} to member."
    end

    def enable_food_tracking
      @user.enable_food_tracking!
      redirect_to admin_root_path, notice: "Enabled food tracking for #{@user.email_address}."
    end

    def disable_food_tracking
      @user.disable_food_tracking!
      redirect_to admin_root_path, notice: "Disabled food tracking for #{@user.email_address}."
    end

    def send_password_reset
      PasswordsMailer.reset(@user).deliver_later
      redirect_to admin_root_path, notice: "Password reset sent."
    end

    def resend_invite
      InvitationsMailer.invite(@user).deliver_later
      redirect_to admin_root_path, notice: "Invitation resent."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def forbid_self
      return unless @user == Current.user

      redirect_to admin_root_path, alert: "You can't do that to your own account."
    end

    def warn_last_admin
      redirect_to admin_root_path, alert: "That would remove the last active admin."
    end

    def user_params
      params.require(:user).permit(:email_address)
    end

    def requested_role
      role = params.dig(:user, :role).to_s
      User.roles.key?(role) ? role : :member
    end
  end
end
