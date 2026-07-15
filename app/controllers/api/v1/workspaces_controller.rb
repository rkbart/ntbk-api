module Api
  module V1
    class WorkspacesController < BaseController
      before_action :set_workspace, only: [ :show, :update ]

      # GET /api/v1/workspaces
      def index
        workspaces = current_user.workspaces
        render json: { data: workspaces.map { |w| WorkspaceSerializer.new(w).as_json } }
      end

      # GET /api/v1/workspaces/:id
      def show
        render json: { data: WorkspaceSerializer.new(@workspace).as_json }
      end

      # POST /api/v1/workspaces
      def create
        workspace = current_user.workspaces.build(workspace_params)

        if workspace.save
          render json: { data: WorkspaceSerializer.new(workspace).as_json }, status: :created
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: workspace.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/workspaces/:id
      def update
        if @workspace.update(workspace_params)
          render json: { data: WorkspaceSerializer.new(@workspace).as_json }
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: @workspace.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      private

      def set_workspace
        @workspace = current_user.workspaces.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Workspace not found" } }, status: :not_found
      end

      def workspace_params
        params.permit(:name)
      end
    end
  end
end
