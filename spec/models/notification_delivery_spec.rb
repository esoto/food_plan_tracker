require "rails_helper"

RSpec.describe NotificationDelivery, type: :model do
  describe ".recent" do
    it "orders by fired_at descending and limits to the given count" do
      described_class.create!(title: "Old", fired_at: 2.hours.ago)
      described_class.create!(title: "New", fired_at: 5.minutes.ago)
      described_class.create!(title: "Mid", fired_at: 1.hour.ago)

      expect(described_class.recent(2).pluck(:title)).to eq(%w[New Mid])
      expect(described_class.recent(10).pluck(:title)).to eq(%w[New Mid Old])
    end

    it "defaults to 20" do
      25.times { |i| described_class.create!(title: "T#{i}", fired_at: i.minutes.ago) }
      expect(described_class.recent.size).to eq(20)
    end
  end
end
