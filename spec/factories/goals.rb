FactoryBot.define do
  factory :goal do
    metric { 1 }
    starting_value { "9.99" }
    target_value { "9.99" }
    unit { "MyString" }
    direction { 1 }
    display_name { "MyString" }
  end
end
