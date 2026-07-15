require 'rails_helper'

RSpec.describe Tag, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      tag = build(:tag)
      expect(tag).to be_valid
    end

    it 'requires name' do
      tag = build(:tag, name: nil)
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("can't be blank")
    end

    it 'requires user' do
      tag = build(:tag, user: nil)
      expect(tag).not_to be_valid
    end

    it 'requires unique name per user' do
      user = create(:user)
      create(:tag, user: user, name: "todo")
      tag = build(:tag, user: user, name: "todo")
      expect(tag).not_to be_valid
      expect(tag.errors[:name]).to include("has already been taken")
    end

    it 'allows same name for different users' do
      user1 = create(:user)
      user2 = create(:user)
      create(:tag, user: user1, name: "todo")
      tag = build(:tag, user: user2, name: "todo")
      expect(tag).to be_valid
    end
  end

  describe 'callbacks' do
    it 'normalizes name to lowercase' do
      tag = create(:tag, name: "TODO")
      expect(tag.name).to eq("todo")
    end

    it 'strips whitespace from name' do
      tag = create(:tag, name: "  todo  ")
      expect(tag.name).to eq("todo")
    end
  end

  describe '#document_count' do
    it 'returns the number of documents with this tag' do
      tag = create(:tag)
      create(:document_tag, tag: tag)
      create(:document_tag, tag: tag)
      expect(tag.document_count).to eq(2)
    end
  end
end
