module Api
  module V1
    module Attachments
      class DownloadController < BaseController
        before_action :set_workspace
        before_action :set_document
        before_action :set_attachment

        # GET /api/v1/workspaces/:workspace_id/documents/:document_id/attachments/:id/download
        def show
          if @attachment.file.attached?
            # Set ActiveStorage::Current.url_options for URL generation
            ActiveStorage::Current.url_options = { host: request.host, port: request.port }

            render json: {
              data: {
                url: @attachment.file.url,
                filename: @attachment.filename,
                content_type: @attachment.content_type,
                file_size: @attachment.file_size
              }
            }
          else
            render json: { error: { code: "NOT_FOUND", message: "File not found" } }, status: :not_found
          end
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
      end
    end
  end
end
