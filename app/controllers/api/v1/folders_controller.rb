module Api
  module V1
    class FoldersController < BaseController
      before_action :set_workspace
      before_action :set_folder, only: [ :show, :update, :destroy ]

      # GET /api/v1/workspaces/:workspace_id/folders
      def index
        folders = @workspace.folders
        folders = folders.where(parent_id: params[:parent_id]) if params[:parent_id].present?
        folders = folders.order(:name)

        render json: { data: folders.map { |f| FolderSerializer.new(f).as_json } }
      end

      # GET /api/v1/workspaces/:workspace_id/folders/:id
      def show
        render json: { data: FolderSerializer.new(@folder).as_json }
      end

      # POST /api/v1/workspaces/:workspace_id/folders
      def create
        folder = @workspace.folders.build(folder_params)

        if folder.save
          render json: { data: FolderSerializer.new(folder).as_json }, status: :created
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: folder.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # PATCH /api/v1/workspaces/:workspace_id/folders/:id
      def update
        if @folder.update(folder_params)
          render json: { data: FolderSerializer.new(@folder).as_json }
        else
          render json: { error: { code: "VALIDATION_ERROR", message: "Validation failed", details: @folder.errors.full_messages } }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/workspaces/:workspace_id/folders/:id
      def destroy
        if @folder.documents.exists?
          render json: { error: { code: "CONFLICT", message: "Cannot delete folder with documents. Move or delete documents first." } }, status: :conflict
        else
          @folder.destroy
          head :no_content
        end
      end

      private

      def set_workspace
        @workspace = current_user.workspaces.find(params[:workspace_id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Workspace not found" } }, status: :not_found
      end

      def set_folder
        @folder = @workspace.folders.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        render json: { error: { code: "NOT_FOUND", message: "Folder not found" } }, status: :not_found
      end

      def folder_params
        params.permit(:name, :parent_id)
      end
    end
  end
end
