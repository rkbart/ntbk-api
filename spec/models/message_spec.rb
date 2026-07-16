require 'rails_helper'

RSpec.describe Message, type: :model do
  describe 'validations' do
    it 'validates role inclusion' do
      message = build(:message, role: "invalid_role")
      expect(message).not_to be_valid
      expect(message.errors[:role]).to include("is not included in the list")
    end

    it 'validates content presence' do
      message = build(:message, content: nil)
      expect(message).not_to be_valid
      expect(message.errors[:content]).to include("can't be blank")
    end
  end

  describe 'scopes' do
    describe '.chronological' do
      it 'orders by created_at ascending' do
        conversation = create(:conversation)
        old_message = create(:message, conversation: conversation, created_at: 2.hours.ago)
        new_message = create(:message, conversation: conversation, created_at: 1.hour.ago)

        expect(Conversation.first.messages.chronological.first).to eq(old_message)
      end
    end
  end

  describe 'methods' do
    describe '#user?' do
      it 'returns true for user role' do
        message = build(:message, role: "user")
        expect(message.user?).to be true
      end

      it 'returns false for non-user role' do
        message = build(:message, role: "assistant")
        expect(message.user?).to be false
      end
    end

    describe '#assistant?' do
      it 'returns true for assistant role' do
        message = build(:message, role: "assistant")
        expect(message.assistant?).to be true
      end

      it 'returns false for non-assistant role' do
        message = build(:message, role: "user")
        expect(message.assistant?).to be false
      end
    end
  end
end
