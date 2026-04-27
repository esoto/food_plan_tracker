class ReminderPreferencesController < ApplicationController
  def update
    params.require(:reminder_type)
    params.require(:key)

    ReminderPreference.set(
      reminder_type: params[:reminder_type],
      key:           params[:key],
      enabled:       ActiveModel::Type::Boolean.new.cast(params[:enabled])
    )

    redirect_to notifications_path, status: :see_other, notice: "Reminder preference updated."
  end
end
