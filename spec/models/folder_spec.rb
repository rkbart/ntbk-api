require 'rails_helper'

RSpec.describe Folder, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      folder = build(:folder)
      expect(folder).to be_valid
    end

    it 'requires name' do
      folder = build(:folder, name: nil)
      expect(folder).not_to be_valid
      expect(folder.errors[:name]).to include("can't be blank")
    end

    it 'requires workspace' do
      folder = build(:folder, workspace: nil)
      expect(folder).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to workspace' do
      folder = create(:folder)
      expect(folder.workspace).to be_present
    end

    it 'can have a parent folder' do
      parent = create(:folder)
      child = create(:folder, parent: parent)
      expect(child.parent).to eq(parent)
    end

    it 'can have subfolders' do
      parent = create(:folder)
      create(:folder, parent: parent)
      create(:folder, parent: parent)
      expect(parent.subfolders.count).to eq(2)
    end

    it 'has many documents' do
      folder = create(:folder)
      create(:document, folder: folder)
      create(:document, folder: folder)
      expect(folder.documents.count).to eq(2)
    end
  end

  describe 'circular reference validation' do
    it 'prevents circular references' do
      parent = create(:folder)
      child = create(:folder, parent: parent)

      child.update(parent_id: nil)
      parent.update(parent_id: child.id)

      expect(child.update(parent_id: parent.id)).to be false
      expect(child.errors[:parent_id]).to include("would create circular reference")
    end
  end

  describe '#path' do
    it 'returns the folder path' do
      root = create(:folder, name: "Root")
      child = create(:folder, name: "Child", parent: root)
      grandchild = create(:folder, name: "Grandchild", parent: child)

      expect(grandchild.path).to eq("Root / Child / Grandchild")
    end
  end
end
