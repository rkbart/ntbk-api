module Api
  module V1
    module Ai
      class SummariesController < BaseController
        # GET /api/v1/workspaces/:workspace_id/documents/:document_id/summary
        def show
          document = find_document
          service = SummaryService.new
          summary = service.generate_summary(document)

          render json: {
            data: {
              document_id: document.id,
              summary: summary,
              generated_at: document.summary_generated_at&.iso8601
            }
          }
        end

        # POST /api/v1/workspaces/:workspace_id/documents/:document_id/summary
        def create
          document = find_document
          service = SummaryService.new
          summary = service.generate_summary(document)

          render json: {
            data: {
              document_id: document.id,
              summary: summary,
              generated_at: document.summary_generated_at&.iso8601
            }
          }
        end

        # POST /api/v1/ai/summaries/generate_workspace/:workspace_id
        def generate_workspace
          workspace = current_user.workspaces.find(params[:workspace_id])
          SummaryJob.perform_later(workspace.id)

          render json: {
            data: {
              message: "Summary generation started for workspace",
              workspace_id: workspace.id
            }
          }
        rescue ActiveRecord::RecordNotFound
          not_found!("Workspace not found")
        end

        private

        def find_document
          workspace = current_user.workspaces.find(params[:workspace_id])
          workspace.documents.find(params[:id])
        rescue ActiveRecord::RecordNotFound
          raise ActiveRecord::RecordNotFound, "Document not found"
        end
      end
    end
  end
end
