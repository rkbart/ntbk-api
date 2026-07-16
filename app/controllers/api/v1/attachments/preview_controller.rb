module Api
  module V1
    module Attachments
      class PreviewController < BaseController
        before_action :set_workspace
        before_action :set_document
        before_action :set_attachment

        # GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id/preview
        def show
          preview = generate_preview

          if preview
            render json: { data: preview }
          else
            render json: {
              error: {
                code: "PREVIEW_UNAVAILABLE",
                message: "Preview not available for this file type"
              }
            }, status: :unprocessable_entity
          end
        end

        private

        def generate_preview
          case @attachment.content_type
          when /^image\//
            image_preview
          when 'application/pdf'
            pdf_preview
          when /^text\//
            text_preview
          else
            nil
          end
        end

        def image_preview
          {
            type: 'image',
            dimensions: @attachment.metadata['dimensions'],
            preview_url: @attachment.thumbnail.attached? ? @attachment.thumbnail.url : nil
          }
        end

        def pdf_preview
          {
            type: 'pdf',
            page_count: @attachment.metadata['page_count'],
            preview_url: @attachment.thumbnail.attached? ? @attachment.thumbnail.url : nil
          }
        end

        def text_preview
          content = @attachment.file.download
          {
            type: 'text',
            content_type: @attachment.content_type,
            content: content.truncate(1000)
          }
        end

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
      end
    end
  end
end
