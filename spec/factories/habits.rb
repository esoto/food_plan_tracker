FactoryBot.define do
  factory :habit do
    user
    label { "MyString" }
    description { "MyString" }
    icon { "MyString" }
    position { 1 }
  end
end
