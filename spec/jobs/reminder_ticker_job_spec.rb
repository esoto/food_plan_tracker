require "rails_helper"

RSpec.describe ReminderTickerJob, type: :job do
  let!(:user1) { create(:user) }
  let!(:user2) { create(:user) }

  before do
    allow(PushNotifier).to receive(:configured?).and_return(true)
  end

  describe "dispatcher behavior" do
    it "enqueues one UserReminderJob per user" do
      now = Time.zone.local(2026, 4, 26, 7, 30)

      expect {
        described_class.perform_now(now: now)
      }.to have_enqueued_job(UserReminderJob).exactly(2).times
    end

    it "enqueues one UserReminderJob per user, forwarding user_id and now" do
      now = Time.zone.local(2026, 4, 26, 7, 30)

      described_class.perform_now(now: now)

      user_ids = enqueued_jobs.map { |j| j[:args].first }
      expect(user_ids).to contain_exactly(user1.id, user2.id)
    end

    it "enqueues nothing when push is not configured" do
      allow(PushNotifier).to receive(:configured?).and_return(false)

      expect {
        described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 30))
      }.not_to change(ActiveJob::Base.queue_adapter.enqueued_jobs, :size)
    end

    it "does no reminder evaluation itself (never calls broadcast)" do
      expect(PushNotifier).not_to receive(:broadcast)
      described_class.perform_now(now: Time.zone.local(2026, 4, 26, 7, 30))
    end
  end
end
