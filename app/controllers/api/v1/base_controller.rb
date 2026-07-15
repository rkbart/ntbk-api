module Api
  module V1
    class BaseController < ApplicationController
      before_action :authenticate_user!

      private

      def authenticate_user!
        token = extract_token_from_header
        return unauthorized!("Missing token") unless token

        decoded = JwtService.decode(token)
        return unauthorized!("Invalid token") unless decoded

        @current_user = User.find_by(id: decoded[:user_id])
        unauthorized!("User not found") unless @current_user
      end

      def current_user
        @current_user
      end

      def extract_token_from_header
        header = request.headers["Authorization"]
        header&.split(" ")&.last
      end

      def unauthorized!(message = "Unauthorized")
        render json: { error: { code: "UNAUTHORIZED", message: message } }, status: :unauthorized
      end

      def not_found!(message = "Resource not found")
        render json: { error: { code: "NOT_FOUND", message: message } }, status: :not_found
      end

      def validation_error!(errors)
        render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: errors } }, status: :unprocessable_entity
      end
    end
  end
end
