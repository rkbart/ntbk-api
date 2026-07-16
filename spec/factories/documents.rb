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

    trait :with_searchable_content do
      title { Faker::Lorem.sentence(word_count: 5) }
      body { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end
  end
end
