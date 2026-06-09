class ChecklistController < ApplicationController
  def show
    @daily_log = today_log
    @templates = Current.user.checklist_templates.kept.ordered
    @completions_by_template = @daily_log.checklist_completions.index_by(&:checklist_template_id)
    @last_30_logs = Current.user.daily_logs
      .where(date: 29.days.ago.to_date..Date.current)
      .includes(:checklist_completions)
      .index_by(&:date)
    @streak = compute_streak
  end

  private

  STREAK_MAX_DAYS = 365

  # Walks back from today counting consecutive days at >=80% adherence.
  # Capped at STREAK_MAX_DAYS to bound the per-day find_by + adherence calc
  # (each iteration is one query + one count). One year of streak is plenty
  # for the UI; nobody will notice a longer one. Reuses the eager-loaded
  # @last_30_logs to skip the per-day DailyLog lookup for the recent window.
  # Note: checklist_adherence_pct still issues per-day COUNTs (kept_on +
  # checked counts) — bounded by STREAK_MAX_DAYS.
  def compute_streak
    count = 0
    date = Date.current
    STREAK_MAX_DAYS.times do
      log = @last_30_logs[date] || Current.user.daily_logs.find_by(date: date)
      break unless log && log.checklist_adherence_pct >= 80

      count += 1
      date -= 1
    end
    count
  end
end
