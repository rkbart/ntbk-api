require 'rails_helper'

RSpec.describe "Api::V1::Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:valid_params) do
      {
        email: "test@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    context "with valid params" do
      it "creates a new user and returns token" do
        post "/api/v1/auth/register", params: valid_params

        expect(response).to have_http_status(:created)
        json = json_response

        expect(json["data"]["email"]).to eq("test@example.com")
        expect(json["token"]).to be_present
        expect(json["expires_at"]).to be_present
      end

      it "creates exactly one user" do
        expect {
          post "/api/v1/auth/register", params: valid_params
        }.to change(User, :count).by(1)
      end
    end

    context "with invalid params" do
      it "returns error for missing email" do
        post "/api/v1/auth/register", params: { password: "password123" }

        expect(response).to have_http_status(:unprocessable_entity)
        expect(json_response["error"]["code"]).to eq("VALIDATION_ERROR")
      end

      it "returns error for short password" do
        post "/api/v1/auth/register", params: valid_params.merge(password: "123")

        expect(response).to have_http_status(:unprocessable_entity)
      end

      it "returns error for duplicate email" do
        create(:user, email: "test@example.com")
        post "/api/v1/auth/register", params: valid_params

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "test@example.com", password: "password123") }

    context "with valid credentials" do
      it "returns token" do
        post "/api/v1/auth/login", params: { email: "test@example.com", password: "password123" }

        expect(response).to have_http_status(:ok)
        json = json_response

        expect(json["token"]).to be_present
        expect(json["data"]["email"]).to eq("test@example.com")
      end
    end

    context "with invalid credentials" do
      it "returns unauthorized for wrong password" do
        post "/api/v1/auth/login", params: { email: "test@example.com", password: "wrong" }

        expect(response).to have_http_status(:unauthorized)
      end

      it "returns unauthorized for non-existent user" do
        post "/api/v1/auth/login", params: { email: "nonexistent@example.com", password: "password123" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "GET /api/v1/auth/me" do
    let(:user) { create(:user) }
    let(:token) { JwtService.encode(user_id: user.id) }
    let(:headers) { { "Authorization" => "Bearer #{token}" } }

    context "with valid token" do
      it "returns user profile" do
        get "/api/v1/auth/me", headers: headers

        expect(response).to have_http_status(:ok)
        json = json_response

        expect(json["data"]["email"]).to eq(user.email)
      end
    end

    context "without token" do
      it "returns unauthorized" do
        get "/api/v1/auth/me"

        expect(response).to have_http_status(:unauthorized)
      end
    end

    context "with invalid token" do
      it "returns unauthorized" do
        get "/api/v1/auth/me", headers: { "Authorization" => "Bearer invalid" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  describe "PATCH /api/v1/auth/me" do
    let(:user) { create(:user, password: "password123") }
    let(:token) { JwtService.encode(user_id: user.id) }
    let(:headers) { { "Authorization" => "Bearer #{token}" } }

    context "with valid params" do
      it "updates user email" do
        patch "/api/v1/auth/me", params: { email: "new@example.com" }, headers: headers

        expect(response).to have_http_status(:ok)
        user.reload
        expect(user.email).to eq("new@example.com")
      end
    end
  end

  describe "POST /api/v1/auth/refresh" do
    let(:user) { create(:user) }
    let(:token) { JwtService.encode(user_id: user.id) }
    let(:headers) { { "Authorization" => "Bearer #{token}" } }

    it "returns new token" do
      post "/api/v1/auth/refresh", headers: headers

      expect(response).to have_http_status(:ok)
      json = json_response

      expect(json["token"]).to be_present
      expect(json["expires_at"]).to be_present
    end
  end
end
