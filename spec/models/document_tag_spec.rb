require 'rails_helper'

RSpec.describe DocumentTag, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      document_tag = build(:document_tag)
      expect(document_tag).to be_valid
    end

    it 'requires document' do
      document_tag = build(:document_tag, document: nil)
      expect(document_tag).not_to be_valid
    end

    it 'requires tag' do
      document_tag = build(:document_tag, tag: nil)
      expect(document_tag).not_to be_valid
    end

    it 'prevents duplicate associations' do
      document = create(:document)
      tag = create(:tag, user: document.workspace.user)
      create(:document_tag, document: document, tag: tag)

      duplicate = build(:document_tag, document: document, tag: tag)
      expect(duplicate).not_to be_valid
      expect(duplicate.errors[:document_id]).to include("has already been taken")
    end
  end

  describe 'associations' do
    it 'belongs to document' do
      document_tag = create(:document_tag)
      expect(document_tag.document).to be_present
    end

    it 'belongs to tag' do
      document_tag = create(:document_tag)
      expect(document_tag.tag).to be_present
    end
  end
end
