module Api
  module V1
    class TagsController < BaseController
      before_action :set_tag, only: [ :destroy ]

      # GET /api/v1/tags
      def index
        tags = current_user.tags.left_joins(:document_tags)
                          .select("tags.*, COUNT(document_tags.document_id) AS document_count")
                          .group("tags.id")
                          .order(:name)

        render json: { data: tags.map { |t| TagSerializer.new(t).as_json } }
      end

      # POST /api/v1/tags
      def create
        tag = current_user.tags.build(tag_params)

        if tag.save
          render json: { data: TagSerializer.new(tag).as_json }, status: :created
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: tag.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/tags/:id
      def destroy
        @tag.destroy
        head :no_content
      end

      private

      def set_tag
        @tag = current_user.tags.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Tag not found" } }, status: :not_found
      end

      def tag_params
        params.permit(:name)
      end
    end
  end
end
