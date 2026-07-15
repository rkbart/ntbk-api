require "rails_helper"

RSpec.describe "Api::V1::Documents", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { user.workspaces.first }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/workspaces/:workspace_id/documents" do
    it "returns all documents" do
      create_list(:document, 3, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/documents", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"].length).to eq(3)
      expect(json["meta"]["total"]).to eq(3)
    end

    it "excludes archived documents by default" do
      create(:document, workspace: workspace)
      create(:document, :archived, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/documents", headers: headers

      json = json_response
      expect(json["data"].length).to eq(1)
    end

    it "filters by folder" do
      folder = create(:folder, workspace: workspace)
      create(:document, workspace: workspace, folder: folder)
      create(:document, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/documents", params: { folder_id: folder.id }, headers: headers

      json = json_response
      expect(json["data"].length).to eq(1)
    end

    it "paginates results" do
      create_list(:document, 25, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/documents", params: { page: 1, per_page: 10 }, headers: headers

      json = json_response
      expect(json["data"].length).to eq(10)
      expect(json["meta"]["total"]).to eq(25)
      expect(json["meta"]["total_pages"]).to eq(3)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/documents" do
    it "creates a new document" do
      post "/api/v1/workspaces/#{workspace.id}/documents",
           params: { title: "New Document", body: "# Hello" },
           headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["title"]).to eq("New Document")
    end

    it "creates document with tags" do
      post "/api/v1/workspaces/#{workspace.id}/documents",
           params: { title: "Tagged", tags: [ "ruby", "rails" ] },
           headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["tags"].length).to eq(2)
    end
  end

  describe "GET /api/v1/workspaces/:workspace_id/documents/:id" do
    it "returns the document" do
      document = create(:document, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"]["id"]).to eq(document.id)
    end
  end

  describe "PATCH /api/v1/workspaces/:workspace_id/documents/:id" do
    it "updates the document" do
      document = create(:document, workspace: workspace)

      patch "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}",
            params: { title: "Updated" },
            headers: headers

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.title).to eq("Updated")
    end
  end

  describe "DELETE /api/v1/workspaces/:workspace_id/documents/:id" do
    it "deletes the document" do
      document = create(:document, workspace: workspace)

      delete "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Document.find_by(id: document.id)).to be_nil
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/documents/:id/archive" do
    it "archives the document" do
      document = create(:document, workspace: workspace)

      post "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}/archive", headers: headers

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.archived?).to be true
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/documents/:id/restore" do
    it "restores the document" do
      document = create(:document, :archived, workspace: workspace)

      post "/api/v1/workspaces/#{workspace.id}/documents/#{document.id}/restore", headers: headers

      expect(response).to have_http_status(:ok)
      document.reload
      expect(document.archived?).to be false
    end
  end
end
