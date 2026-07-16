require 'rails_helper'

RSpec.describe Conversation, type: :model do
  describe 'validations' do
    it 'validates title length' do
      conversation = build(:conversation, title: "a" * 256)
      expect(conversation).not_to be_valid
      expect(conversation.errors[:title]).to include("is too long (maximum is 255 characters)")
    end
  end

  describe 'scopes' do
    describe '.recent' do
      it 'orders by last_message_at descending' do
        old_conversation = create(:conversation, last_message_at: 2.hours.ago)
        new_conversation = create(:conversation, last_message_at: 1.hour.ago)

        expect(Conversation.recent.first).to eq(new_conversation)
      end
    end
  end

  describe 'methods' do
    describe '#last_message' do
      it 'returns the most recent message' do
        conversation = create(:conversation)
        old_message = create(:message, conversation: conversation, created_at: 2.hours.ago)
        new_message = create(:message, conversation: conversation, created_at: 1.hour.ago)

        expect(conversation.last_message).to eq(new_message)
      end
    end

    describe '#message_count' do
      it 'returns the count of messages' do
        conversation = create(:conversation)
        create_list(:message, 3, conversation: conversation)

        expect(conversation.message_count).to eq(3)
      end
    end
  end
end
