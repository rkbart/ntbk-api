require "rails_helper"

RSpec.describe "Api::V1::Workspaces", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/workspaces" do
    it "returns all workspaces for current user" do
      # User already has default workspace from callback
      create(:workspace, user: user)

      get "/api/v1/workspaces", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"].length).to eq(2)
    end

    it "returns unauthorized without token" do
      get "/api/v1/workspaces"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/workspaces/:id" do
    it "returns the workspace" do
      workspace = create(:workspace, user: user)

      get "/api/v1/workspaces/#{workspace.id}", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"]["id"]).to eq(workspace.id)
      expect(json["data"]["name"]).to eq(workspace.name)
    end

    it "returns not found for non-existent workspace" do
      get "/api/v1/workspaces/999999", headers: headers

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/workspaces" do
    it "creates a new workspace" do
      post "/api/v1/workspaces", params: { name: "New Workspace" }, headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["name"]).to eq("New Workspace")
    end

    it "returns error for invalid params" do
      post "/api/v1/workspaces", params: { name: "" }, headers: headers

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/workspaces/:id" do
    it "updates the workspace" do
      workspace = create(:workspace, user: user)

      patch "/api/v1/workspaces/#{workspace.id}", params: { name: "Updated" }, headers: headers

      expect(response).to have_http_status(:ok)
      workspace.reload
      expect(workspace.name).to eq("Updated")
    end
  end
end
