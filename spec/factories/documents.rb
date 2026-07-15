FactoryBot.define do
  factory :document do
    sequence(:title) { |n| "Document #{n}" }
    body { "# Test Document\n\nThis is a test." }
    workspace

    trait :archived do
      archived_at { Time.current }
    end

    trait :in_folder do
      folder
    end
  end
end
