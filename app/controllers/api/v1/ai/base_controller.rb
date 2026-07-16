module Api
  module V1
    module Ai
      class BaseController < Api::V1::BaseController
        private

        def not_found!(message = "Not found")
          render json: { error: { code: "NOT_FOUND", message: message } }, status: :not_found
        end

        def validation_error!(message)
          render json: { error: { code: "VALIDATION_ERROR", message: message } }, status: :unprocessable_entity
        end

        def pagination_meta(collection)
          {
            page: collection.current_page,
            per_page: collection.limit_value,
            total: collection.total_count,
            total_pages: collection.total_pages
          }
        end
      end
    end
  end
end
