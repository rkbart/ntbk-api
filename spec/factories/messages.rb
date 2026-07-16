FactoryBot.define do
  factory :message do
    conversation
    role { "user" }
    content { "Test message content" }
    document_references { [] }
  end
end
