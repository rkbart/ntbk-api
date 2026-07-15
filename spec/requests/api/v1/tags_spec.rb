require "rails_helper"

RSpec.describe "Api::V1::Tags", type: :request do
  let(:user) { create(:user) }
  let(:token) { JwtService.encode(user_id: user.id) }
  let(:headers) { { "Authorization" => "Bearer #{token}" } }

  describe "GET /api/v1/tags" do
    it "returns all tags with document count" do
      tag1 = create(:tag, user: user, name: "rails")
      tag2 = create(:tag, user: user, name: "todo")
      document = create(:document, workspace: user.workspaces.first)
      create(:document_tag, document: document, tag: tag1)

      get "/api/v1/tags", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response
      expect(json["data"].length).to eq(2)
    end
  end

  describe "POST /api/v1/tags" do
    it "creates a new tag" do
      post "/api/v1/tags", params: { name: "new-tag" }, headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["name"]).to eq("new-tag")
    end

    it "normalizes tag name to lowercase" do
      post "/api/v1/tags", params: { name: "TODO" }, headers: headers

      expect(response).to have_http_status(:created)
      json = json_response
      expect(json["data"]["name"]).to eq("todo")
    end
  end

  describe "DELETE /api/v1/tags/:id" do
    it "deletes the tag" do
      tag = create(:tag, user: user)

      delete "/api/v1/tags/#{tag.id}", headers: headers

      expect(response).to have_http_status(:no_content)
      expect(Tag.find_by(id: tag.id)).to be_nil
    end
  end
end
