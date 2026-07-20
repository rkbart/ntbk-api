module Api
  module V1
    module Ai
      class ReformatController < BaseController
        REFORMAT_PROMPT = <<~PROMPT
          You are a markdown formatting assistant. Your task is to reformat and clean up the given markdown content.

          RULES:
          1. Fix heading hierarchy (h1 > h2 > h3, no skipping levels)
          2. Ensure consistent spacing between sections (one blank line between headings and content)
          3. Fix list formatting (proper indentation, consistent markers)
          4. Clean up code blocks (ensure proper fencing)
          5. Fix table formatting if present
          6. Remove excessive blank lines (max 2 consecutive)
          7. Ensure proper spacing around inline code, bold, and italic
          8. DO NOT change the content or meaning
          9. DO NOT add new content
          10. ONLY return the reformatted markdown, nothing else

          Output the cleaned-up markdown only.
        PROMPT

        # POST /api/v1/ai/reformat
        def create
          content = params[:content]

          if content.blank?
            render json: { error: { code: "VALIDATION_ERROR", message: "Content is required" } }, status: :unprocessable_entity
            return
          end

          client = LlmClientFactory.create
          messages = [
            { role: "system", content: REFORMAT_PROMPT },
            { role: "user", content: content }
          ]

          reformatted = client.chat(messages, temperature: 0.3, max_tokens: 4096)

          if reformatted.blank?
            render json: { error: { code: "AI_ERROR", message: "Failed to reformat content" } }, status: :unprocessable_entity
            return
          end

          render json: { data: { content: reformatted } }
        end
      end
    end
  end
end
