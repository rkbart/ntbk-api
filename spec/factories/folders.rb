FactoryBot.define do
  factory :folder do
    sequence(:name) { |n| "Folder #{n}" }
    workspace

    trait :with_parent do
      parent
    end
  end
end
