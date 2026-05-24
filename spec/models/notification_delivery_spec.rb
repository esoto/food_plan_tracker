require "rails_helper"

RSpec.describe NotificationDelivery, type: :model do
  let(:user) { create(:user) }

  describe ".for_user" do
    it "returns only the given user's deliveries" do
      user_a = create(:user)
      user_b = create(:user)
      mine = create(:notification_delivery, user: user_a)
      create(:notification_delivery, user: user_b)

      expect(NotificationDelivery.for_user(user_a)).to contain_exactly(mine)
    end

    it "returns no records when passed nil" do
      create(:notification_delivery, user: create(:user))

      expect(NotificationDelivery.for_user(nil)).to be_empty
    end
  end

  describe ".recent" do
    it "orders by fired_at descending and limits to the given count" do
      described_class.create!(title: "Old", fired_at: 2.hours.ago, user: user)
      described_class.create!(title: "New", fired_at: 5.minutes.ago, user: user)
      described_class.create!(title: "Mid", fired_at: 1.hour.ago, user: user)

      expect(described_class.recent(2).pluck(:title)).to eq(%w[New Mid])
      expect(described_class.recent(10).pluck(:title)).to eq(%w[New Mid Old])
    end

    it "defaults to 20" do
      25.times { |i| described_class.create!(title: "T#{i}", fired_at: i.minutes.ago, user: user) }
      expect(described_class.recent.size).to eq(20)
    end
  end
end
