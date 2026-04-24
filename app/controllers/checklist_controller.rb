class ChecklistController < ApplicationController
  def show
    @daily_log = today_log
    @templates = ChecklistTemplate.ordered
    @completions_by_template = @daily_log.checklist_completions.index_by(&:checklist_template_id)
    @last_30_logs = DailyLog.where(date: 29.days.ago.to_date..Date.current).includes(:checklist_completions).index_by(&:date)
    @streak = compute_streak
  end

  private

  def compute_streak
    count = 0
    date = Date.current
    loop do
      log = DailyLog.find_by(date: date)
      break unless log && log.checklist_adherence_pct >= 80

      count += 1
      date -= 1
    end
    count
  end
end
