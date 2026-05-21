FactoryBot.define do
  factory :checklist_template do
    user
    label { "MyString" }
    description { "MyString" }
    icon { "MyString" }
    position { 1 }
  end
end
