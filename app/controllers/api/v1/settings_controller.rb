module Api
  module V1
    class SettingsController < BaseController
      before_action :authenticate_user!

      # GET /api/v1/settings/profile
      def profile
        render json: {
          data: {
            user: {
              id: current_user.id,
              email: current_user.email,
              name: current_user.name,
              has_password: current_user.has_password?,
              oauth_providers: current_user.oauth_identities.pluck(:provider)
            }
          }
        }
      end

      # PATCH /api/v1/settings/profile
      def update_profile
        if current_user.update(profile_params)
          render json: {
            data: {
              user: {
                id: current_user.id,
                email: current_user.email,
                name: current_user.name
              }
            }
          }
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Update failed", details: current_user.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/settings/password
      def update_password
        # For OAuth users without a password, skip current password validation
        if current_user.has_password?
          # Existing password user - require current password
          unless current_user.valid_password?(params[:current_password])
            render json: { error: { code: "INVALID_PASSWORD", message: "Current password is incorrect" } }, status: :unprocessable_entity
            return
          end
        end

        if current_user.update(password_params.merge(password_set_by_user: true))
          render json: { data: { message: "Password updated successfully" } }
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Password update failed", details: current_user.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      private

      def profile_params
        params.permit(:name, :email)
      end

      def password_params
        params.permit(:password, :password_confirmation)
      end
    end
  end
end
