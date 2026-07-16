class SummaryJob < ApplicationJob
  queue_as :ai

  retry_on StandardError, wait: :polynomially_longer, attempts: 3

  def perform(workspace_id)
    workspace = Workspace.find(workspace_id)
    documents = workspace.documents.active.where(summary: nil)

    service = SummaryService.new
    service.generate_summaries(documents)

    Rails.logger.info "Generated summaries for #{documents.count} documents in workspace #{workspace_id}"
  end
end
