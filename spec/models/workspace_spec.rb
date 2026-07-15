require 'rails_helper'

RSpec.describe Workspace, type: :model do
  describe 'validations' do
    it 'is valid with valid attributes' do
      workspace = build(:workspace)
      expect(workspace).to be_valid
    end

    it 'requires name' do
      workspace = build(:workspace, name: nil)
      expect(workspace).not_to be_valid
      expect(workspace.errors[:name]).to include("can't be blank")
    end

    it 'requires user' do
      workspace = build(:workspace, user: nil)
      expect(workspace).not_to be_valid
    end
  end

  describe 'associations' do
    it 'belongs to user' do
      workspace = create(:workspace)
      expect(workspace.user).to be_present
    end

    it 'has many folders' do
      workspace = create(:workspace)
      create(:folder, workspace: workspace)
      create(:folder, workspace: workspace)
      expect(workspace.folders.count).to eq(2)
    end

    it 'has many documents' do
      workspace = create(:workspace)
      create(:document, workspace: workspace)
      create(:document, workspace: workspace)
      expect(workspace.documents.count).to eq(2)
    end

    it 'destroys dependent folders' do
      workspace = create(:workspace)
      create(:folder, workspace: workspace)
      expect { workspace.destroy }.to change(Folder, :count).by(-1)
    end

    it 'destroys dependent documents' do
      workspace = create(:workspace)
      create(:document, workspace: workspace)
      expect { workspace.destroy }.to change(Document, :count).by(-1)
    end
  end
end
