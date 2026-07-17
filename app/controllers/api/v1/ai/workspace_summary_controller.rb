module Api
  module V1
    module Ai
      class WorkspaceSummaryController < BaseController
        before_action :set_workspace

        # POST /api/v1/workspaces/:workspace_id/summary
        def create
          service = WorkspaceSummaryService.new(@workspace)
          summary = service.generate_summary

          render json: {
            data: {
              workspace_id: @workspace.id,
              workspace_name: @workspace.name,
              summary: summary,
              document_count: @workspace.documents.active.count,
              generated_at: Time.current.iso8601
            }
          }
        end

        private

        def set_workspace
          @workspace = current_user.workspaces.find(params[:workspace_id])
        rescue ActiveRecord::RecordNotFound
          render json: { error: { code: "NOT_FOUND", message: "Workspace not found" } }, status: :not_found
        end
      end
    end
  end
end
