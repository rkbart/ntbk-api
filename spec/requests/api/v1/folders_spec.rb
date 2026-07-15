require "rails_helper"

RSpec.describe "Api::V1::Folders", type: :request do
  let(:user) { create(:user) }
  let(:workspace) { user.workspaces.first }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/workspaces/:workspace_id/folders" do
    it "returns all folders" do
      create(:folder, workspace: workspace)
      create(:folder, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/folders", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"].length).to eq(2)
    end

    it "filters by parent_id" do
      parent = create(:folder, workspace: workspace)
      create(:folder, workspace: workspace, parent: parent)
      create(:folder, workspace: workspace)

      get "/api/v1/workspaces/#{workspace.id}/folders", params: { parent_id: parent.id }, headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"].length).to eq(1)
    end
  end

  describe "POST /api/v1/workspaces/:workspace_id/folders" do
    it "creates a new folder" do
      post "/api/v1/workspaces/#{workspace.id}/folders", params: { name: "New Folder" }, headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["name"]).to eq("New Folder")
    end

    it "creates a nested folder" do
      parent = create(:folder, workspace: workspace)

      post "/api/v1/workspaces/#{workspace.id}/folders", params: { name: "Child", parent_id: parent.id }, headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["parent_id"]).to eq(parent.id)
    end
  end

  describe "PATCH /api/v1/workspaces/:workspace_id/folders/:id" do
    it "updates the folder" do
      folder = create(:folder, workspace: workspace)

      patch "/api/v1/workspaces/#{workspace.id}/folders/#{folder.id}", params: { name: "Updated" }, headers: headers

      expect(response).to have_http_status(:ok)
      folder.reload
      expect(folder.name).to eq("Updated")
    end
  end

  describe "DELETE /api/v1/workspaces/:workspace_id/folders/:id" do
    it "deletes the folder" do
      folder = create(:folder, workspace: workspace)

      delete "/api/v1/workspaces/#{workspace.id}/folders/#{folder.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Folder.find_by(id: folder.id)).to be_nil
    end

    it "returns conflict if folder has documents" do
      folder = create(:folder, workspace: workspace)
      create(:document, workspace: workspace, folder: folder)

      delete "/api/v1/workspaces/#{workspace.id}/folders/#{folder.id}", headers: headers

      expect(response).to have_http_status(:conflict)
    end
  end
end
