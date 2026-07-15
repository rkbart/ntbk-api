require 'rails_helper'

RSpec.describe Document, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      document = build(:document)
      expect(document).to be_valid
    end

    it 'requires title' do
      document = build(:document, title: nil)
      expect(document).not_to be_valid
      expect(document.errors[:title]).to include("can't be blank")
    end

    it 'requires workspace' do
      document = build(:document, workspace: nil)
      expect(document).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to workspace' do
      document = create(:document)
      expect(document.workspace).to be_present
    end

    it 'can belong to a folder' do
      folder = create(:folder)
      document = create(:document, folder: folder)
      expect(document.folder).to eq(folder)
    end

    it 'can have tags' do
      document = create(:document)
      tag = create(:tag, user: document.workspace.user)
      create(:document_tag, document: document, tag: tag)
      expect(document.tags.count).to eq(1)
    end
  end

  describe 'scopes' do
    it 'returns active documents' do
      active = create(:document)
      archived = create(:document, :archived)

      expect(Document.active).to include(active)
      expect(Document.active).not_to include(archived)
    end

    it 'returns archived documents' do
      active = create(:document)
      archived = create(:document, :archived)

      expect(Document.archived).to include(archived)
      expect(Document.archived).not_to include(active)
    end
  end

  describe '#archive!' do
    it 'archives the document' do
      document = create(:document)
      document.archive!
      expect(document.archived?).to be true
      expect(document.archived_at).to be_present
    end
  end

  describe '#restore!' do
    it 'restores the document' do
      document = create(:document, :archived)
      document.restore!
      expect(document.archived?).to be false
      expect(document.archived_at).to be_nil
    end
  end

  describe '#body_preview' do
    it 'returns truncated body' do
      document = build(:document, body: "x" * 300)
      expect(document.body_preview(100).length).to eq(100)
    end

    it 'returns empty string if body is nil' do
      document = build(:document, body: nil)
      expect(document.body_preview).to eq("")
    end
  end
end
