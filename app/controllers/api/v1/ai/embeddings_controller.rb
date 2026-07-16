module Api
  module V1
    module Ai
      class EmbeddingsController < BaseController
        # POST /api/v1/ai/embeddings
        def create
          text = params[:text]
          return validation_error!("Text is required") if text.blank?

          client = OllamaClient.new
          embedding = client.embed(text)

          render json: {
            data: {
              embedding: embedding,
              model: ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text"),
              dimensions: embedding.length
            }
          }
        end

        # POST /api/v1/ai/embeddings/search
        def search
          query = params[:query]
          workspace_id = params[:workspace_id]
          limit = (params[:limit] || 10).to_i

          return validation_error!("Query is required") if query.blank?
          return validation_error!("Workspace ID is required") if workspace_id.blank?

          workspace = current_user.workspaces.find(workspace_id)
          service = EmbeddingService.new
          results = service.search(query, workspace: workspace, limit: limit)

          render json: {
            data: results.map { |doc|
              DocumentSerializer.new(doc).as_json.merge(distance: doc.neighbor_distance)
            },
            meta: {
              query: query,
              count: results.length,
              model: ENV.fetch("OLLAMA_EMBEDDING_MODEL", "nomic-embed-text")
            }
          }
        rescue ActiveRecord::RecordNotFound
          not_found!("Workspace not found")
        end

        # POST /api/v1/ai/embeddings/similar/:document_id
        def similar
          document = find_document
          service = EmbeddingService.new
          results = service.similar_documents(document, limit: params[:limit]&.to_i || 5)

          render json: {
            data: results.map { |doc|
              DocumentSerializer.new(doc).as_json.merge(distance: doc.neighbor_distance)
            },
            meta: {
              document_id: document.id,
              count: results.length
            }
          }
        end

        # POST /api/v1/ai/embeddings/generate/:document_id
        def generate
          document = find_document
          service = EmbeddingService.new
          service.embed_document(document)

          render json: {
            data: {
              document_id: document.id,
              embedding_generated: true,
              dimensions: 768
            }
          }
        end

        # POST /api/v1/ai/embeddings/generate_workspace/:workspace_id
        def generate_workspace
          workspace = current_user.workspaces.find(params[:workspace_id])
          EmbeddingJob.perform_later(workspace.id)

          render json: {
            data: {
              message: "Embedding generation started for workspace",
              workspace_id: workspace.id
            }
          }
        rescue ActiveRecord::RecordNotFound
          not_found!("Workspace not found")
        end

        private

        def find_document
          workspace = current_user.workspaces.find(params[:workspace_id])
          workspace.documents.find(params[:document_id])
        rescue ActiveRecord::RecordNotFound
          not_found!("Document not found")
        end
      end
    end
  end
end
