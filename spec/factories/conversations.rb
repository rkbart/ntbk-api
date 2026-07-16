FactoryBot.define do
  factory :conversation do
    user
    title { "Test Conversation" }
    last_message_at { Time.current }
  end
end
