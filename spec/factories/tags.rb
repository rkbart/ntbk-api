FactoryBot.define do
  factory :tag do
    sequence(:name) { |n| "tag#{n}" }
    user
  end
end
