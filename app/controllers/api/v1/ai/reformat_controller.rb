module Api
  module V1
    module Ai
      class ReformatController < BaseController
        REFORMAT_PROMPT = <<~PROMPT
          Output ONLY raw markdown. No explanations, no preamble, no commentary, no code fences around the output.

          Task: Reformat the given markdown to fix:
          - Heading hierarchy (h1 > h2 > h3, no skipping levels)
          - Consistent spacing (one blank line between sections)
          - List formatting (proper indentation)
          - Code block fencing
          - Excessive blank lines (max 2 consecutive)
          - Spacing around inline code, bold, italic

          DO NOT change content or meaning. DO NOT add new content.
          Your response MUST start with the first character of the markdown. Nothing before it.
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

          # Aggressively strip AI preamble/suffix
          reformatted = reformatted
            .gsub(/```markdown\s*/i, '')
            .gsub(/```\s*\z/, '')
            .gsub(/\A\s*```[^\n]*\n/, '')
            .gsub(/\A[^\n]*?Here is[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?Here's[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?rewritten[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?reformatted[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?cleaned[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?below is[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?following is[^\n]*:\s*\n*/i, '')
            .gsub(/\A[^\n]*?easier to read[^\n]*:\s*\n*/i, '')
            .strip

          render json: { data: { content: reformatted } }
        end
      end
    end
  end
end
