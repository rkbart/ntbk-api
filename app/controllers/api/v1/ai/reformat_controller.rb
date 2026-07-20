module Api
  module V1
    module Ai
      class ReformatController < BaseController
        REFORMAT_PROMPT = <<~PROMPT
          You are a markdown formatting tool. You receive markdown text and must return ONLY the cleaned-up version.

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
          10. DO NOT add any explanation, prefix, suffix, or commentary
          11. DO NOT wrap in code fences
          12. START your response with the first character of the markdown content

          Your entire response must be the reformatted markdown and nothing else. No greetings, no explanations, no "here is" text.
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

          # Strip common AI prefixes/suffixes
          reformatted = reformatted
            .gsub(/^```markdown\\n/i, '')
            .gsub(/^```\\n/i, '')
            .gsub(/\\n```$/, '')
            .gsub(/^Here is .+?:\\s*/i, '')
            .gsub(/^Here's .+?:\\s*/i, '')
            .gsub(/^The reformatted .+?:\\s*/i, '')
            .strip

          render json: { data: { content: reformatted } }
        end
      end
    end
  end
end
