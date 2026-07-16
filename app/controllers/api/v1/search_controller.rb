module Api
  module V1
    class SearchController < BaseController
      before_action :validate_query!

      # GET /api/v1/search?q=query&page=1&per_page=20
      def index
        result = SearchService.new(
          user: current_user,
          query: params[:q],
          params: search_params
        ).call

        render json: {
          data: result[:documents].map { |d| SearchResultSerializer.new(d).as_json },
          meta: result[:meta]
        }
      end

      private

      def validate_query!
        if params[:q].blank?
          render json: {
            error: {
              code: "VALIDATION_ERROR",
              message: "Search query is required",
              details: [ { field: "q", message: "must be present" } ]
            }
          }, status: :unprocessable_entity
        end
      end

      def search_params
        params.permit(:page, :per_page, :archived)
      end
    end
  end
end
