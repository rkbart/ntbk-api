module Api
  module V1
    module Ai
      class ChatController < BaseController
        # GET /api/v1/ai/conversations
        def index
          conversations = current_user.conversations
            .where(workspace_id: params[:workspace_id])
            .recent
            .page(params[:page])
            .per(params[:per_page] || 20)

          render json: {
            data: conversations.map { |c| ConversationSerializer.new(c).as_json },
            meta: pagination_meta(conversations)
          }
        end

        # POST /api/v1/ai/conversations
        def create
          conversation = current_user.conversations.create!(
            title: params[:title] || "New Conversation",
            workspace_id: params[:workspace_id]
          )

          render json: { data: ConversationSerializer.new(conversation).as_json }, status: :created
        end

        # GET /api/v1/ai/conversations/:id
        def show
          conversation = current_user.conversations.find(params[:id])

          render json: {
            data: ConversationSerializer.new(conversation).as_json.merge(
              messages: conversation.messages.chronological.map { |m|
                MessageSerializer.new(m).as_json
              }
            )
          }
        rescue ActiveRecord::RecordNotFound
          not_found!("Conversation not found")
        end

        # DELETE /api/v1/ai/conversations/:id
        def destroy
          conversation = current_user.conversations.find(params[:id])
          conversation.destroy
          head :no_content
        rescue ActiveRecord::RecordNotFound
          not_found!("Conversation not found")
        end

        # POST /api/v1/ai/chat
        def send_message
          conversation = find_or_create_conversation
          service = ChatService.new(conversation)

          message = service.send_message(
            params[:message],
            document_ids: params[:document_ids] || [],
            workspace_id: params[:workspace_id]
          )

          render json: {
            data: MessageSerializer.new(message).as_json,
            meta: {
              conversation_id: conversation.id,
              model: ENV.fetch("OLLAMA_CHAT_MODEL", "llama3:8b")
            }
          }
        end

        # POST /api/v1/ai/chat/stream (SSE endpoint)
        def send_message_stream
          conversation = find_or_create_conversation
          service = ChatService.new(conversation)

          response.headers["Content-Type"] = "text/event-stream"
          response.headers["Cache-Control"] = "no-cache"
          response.headers["Connection"] = "keep-alive"

          service.send_message_stream(
            params[:message],
            document_ids: params[:document_ids] || [],
            workspace_id: params[:workspace_id]
          ) do |chunk|
            response.stream.write("data: #{chunk.to_json}\n\n")
          end

          response.stream.write("data: [DONE]\n\n")
        rescue => e
          response.stream.write("data: #{ { error: e.message }.to_json }\n\n")
        ensure
          response.stream.close
        end

        private

        def find_or_create_conversation
          if params[:conversation_id].present?
            current_user.conversations.find(params[:conversation_id])
          else
            current_user.conversations.create!(
              title: params[:message]&.truncate(50) || "New Conversation",
              workspace_id: params[:workspace_id]
            )
          end
        rescue ActiveRecord::RecordNotFound
          not_found!("Conversation not found")
        end
      end
    end
  end
end
