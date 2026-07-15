module Api
  module V1
    class AuthController < BaseController
      skip_before_action :authenticate_user!, only: [ :register, :login ]

      # POST /api/v1/auth/register
      def register
        user = User.new(register_params)

        if user.save
          token = JwtService.encode(user_id: user.id)
          render json: {
            data: UserSerializer.new(user).as_json,
            token: token,
            expires_at: 24.hours.from_now.iso8601
          }, status: :created
        else
          validation_error!(user.errors.full_messages)
        end
      end

      # POST /api/v1/auth/login
      def login
        user = User.find_by(email: params[:email]&.downcase)

        if user&.valid_password?(params[:password])
          token = JwtService.encode(user_id: user.id)
          render json: {
            data: UserSerializer.new(user).as_json,
            token: token,
            expires_at: 24.hours.from_now.iso8601
          }
        else
          unauthorized!("Invalid email or password")
        end
      end

      # GET /api/v1/auth/me
      def me
        render json: { data: UserSerializer.new(current_user).as_json }
      end

      # PATCH /api/v1/auth/me
      def update_profile
        if current_user.update(profile_params)
          render json: { data: UserSerializer.new(current_user).as_json }
        else
          validation_error!(current_user.errors.full_messages)
        end
      end

      # POST /api/v1/auth/refresh
      def refresh
        token = JwtService.encode(user_id: current_user.id)
        render json: {
          token: token,
          expires_at: 24.hours.from_now.iso8601
        }
      end

      private

      def register_params
        params.permit(:email, :password, :password_confirmation)
      end

      def profile_params
        params.permit(:email, :password, :password_confirmation, :current_password)
      end
    end
  end
end
