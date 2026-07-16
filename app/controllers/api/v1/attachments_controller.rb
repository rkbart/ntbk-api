module Api
  module V1
    class AttachmentsController < BaseController
      before_action :set_workspace
      before_action :set_document
      before_action :set_attachment, only: [:show, :destroy]

      # GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments
      def index
        attachments = @document.attachments
        attachments = attachments.by_type(params[:type]) if params[:type].present?
        attachments = attachments.order(created_at: :desc)
                                 .page(params[:page])
                                 .per(params[:per_page] || 20)

        render json: {
          data: attachments.map { |a| AttachmentSerializer.new(a).as_json },
          meta: {
            page: (params[:page] || 1).to_i,
            per_page: (params[:per_page] || 20).to_i,
            total: attachments.total_count,
            total_pages: attachments.total_pages
          }
        }
      end

      # GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id
      def show
        render json: {
          data: AttachmentSerializer.new(@attachment).as_json
        }
      end

      # POST /api/v1/workspaces/:workspace_id/documents/:document_id/attachments
      def create
        attachment = @document.attachments.build(attachment_params)

        if params[:file].present?
          attachment.file.attach(params[:file])
          attachment.filename = params[:file].original_filename
          attachment.content_type = params[:file].content_type
          attachment.file_size = params[:file].size
        end

        if attachment.save
          render json: {
            data: AttachmentSerializer.new(attachment).as_json
          }, status: :created
        else
          render json: {
            error: {
              code: "VALIDATION_ERROR",
              message: "Validation failed",
              details: attachment.errors.full_messages
            }
          }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id
      def destroy
        @attachment.destroy
        head :no_content
      end

      private

      def set_workspace
        @workspace = current_user.workspaces.find(params[:workspace_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Workspace not found" } }, status: :not_found
      end

      def set_document
        @document = @workspace.documents.find(params[:document_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Document not found" } }, status: :not_found
      end

      def set_attachment
        @attachment = @document.attachments.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Attachment not found" } }, status: :not_found
      end

      def attachment_params
        params.permit(:filename, :content_type, :file_size, :metadata, :preview_state)
      end
    end
  end
end
