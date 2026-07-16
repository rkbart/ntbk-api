require 'rails_helper'

RSpec.describe 'Api::V1::Attachments', type: :request do
  let(:user) { create(:user) }
  let(:workspace) { user.workspaces.first }
  let(:document) { create(:document, workspace: workspace) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { 'Authorization' => "Bearer #{token}" } }

  describe 'GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments' do
    before do
      create_list(:attachment, 3, document: document)
    end

    it 'returns attachments for the document' do
      get "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}/attachments", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json['data'].length).to eq(3)
    end
  end

  describe 'POST /api/v1/workspaces/:workspace_id/documents/:document_id/attachments' do
    let(:file) { fixture_file_upload('spec/fixtures/files/test.txt', 'text/plain') }

    it 'creates attachment with valid file' do
      post "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}/attachments",
           params: { file: file },
           headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json['data']['filename']).to eq('test.txt')
    end
  end

  describe 'GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id' do
    let(:attachment) { create(:attachment, document: document) }

    it 'returns attachment details' do
      get "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}/attachments/#{attachment.id}",
          headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json['data']['id']).to eq(attachment.id)
    end
  end

  describe 'DELETE /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id' do
    let(:attachment) { create(:attachment, document: document) }

    it 'deletes the attachment' do
      delete "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}/attachments/#{attachment.id}",
             headers: headers

      expect(response).to have_http_status(:no_content)
      expect { attachment.reload }.to raise_error(ActiveRecord::RecordNotFound)
    end
  end
end
