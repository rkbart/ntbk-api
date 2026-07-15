module Api
  module V1
    class DocumentsController < BaseController
      before_action :set_workspace
      before_action :set_document, only: [ :show, :update, :destroy, :archive, :restore ]

      # GET /api/v1/workspaces/:workspace_id/documents
      def index
        documents = @workspace.documents.includes(:folder, :tags)
        documents = apply_filters(documents)
        documents = apply_sorting(documents)

        page = (params[:page] || 1).to_i
        per_page = (params[:per_page] || 20).to_i.clamp(1, 100)
        documents = documents.page(page).per(per_page)

        render json: {
          data: documents.map { |d| DocumentSerializer.new(d).as_json },
          meta: {
            page: page,
            per_page: per_page,
            total: documents.total_count,
            total_pages: documents.total_pages
          }
        }
      end

      # GET /api/v1/workspaces/:workspace_id/documents/:id
      def show
        render json: { data: DocumentSerializer.new(@document).as_json }
      end

      # POST /api/v1/workspaces/:workspace_id/documents
      def create
        document = @workspace.documents.build(document_params)

        if params[:tags].present?
          document.tags = find_or_create_tags(params[:tags])
        end

        if document.save
          render json: { data: DocumentSerializer.new(document).as_json }, status: :created
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: document.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/workspaces/:workspace_id/documents/:id
      def update
        if params[:tags].present?
          @document.tags = find_or_create_tags(params[:tags])
        end

        if @document.update(document_params.except(:tags))
          render json: { data: DocumentSerializer.new(@document).as_json }
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: @document.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/workspaces/:workspace_id/documents/:id
      def destroy
        @document.destroy
        head :no_content
      end

      # POST /api/v1/workspaces/:workspace_id/documents/:id/archive
      def archive
        if @document.archived?
          render json: { error: { code: "CONFLICT", message: "Document is already archived" } }, status: :conflict
        else
          @document.archive!
          render json: { data: { id: @document.id, archived_at: @document.archived_at } }
        end
      end

      # POST /api/v1/workspaces/:workspace_id/documents/:id/restore
      def restore
        unless @document.archived?
          render json: { error: { code: "CONFLICT", message: "Document is not archived" } }, status: :conflict
        else
          @document.restore!
          render json: { data: { id: @document.id, archived_at: nil } }
        end
      end

      private

      def set_workspace
        @workspace = current_user.workspaces.find(params[:workspace_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Workspace not found" } }, status: :not_found
      end

      def set_document
        @document = @workspace.documents.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Document not found" } }, status: :not_found
      end

      def document_params
        params.permit(:title, :body, :folder_id)
      end

      def apply_filters(documents)
        documents = documents.active unless params[:archived] == "true"
        documents = documents.by_folder(params[:folder_id]) if params[:folder_id].present?
        documents = documents.by_tag(params[:tag]) if params[:tag].present?
        documents
      end

      def apply_sorting(documents)
        sort_field = %w[created_at updated_at title].include?(params[:sort]) ? params[:sort] : "updated_at"
        sort_order = params[:order] == "asc" ? :asc : :desc
        documents.order(sort_field => sort_order)
      end

      def find_or_create_tags(tag_names)
        tag_names.map do |name|
          current_user.tags.find_or_create_by!(name: name.downcase.strip)
        end
      end
    end
  end
end
