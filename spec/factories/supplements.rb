FactoryBot.define do
  factory :supplement do
    name { "MyString" }
    dose { "MyString" }
    notes { "MyString" }
    critical { false }
    contraindications { "MyString" }
  end
end
