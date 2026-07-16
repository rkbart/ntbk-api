class AddSummaryToDocuments < ActiveRecord::Migration[8.1]
  def change
    add_column :documents, :summary, :text
    add_column :documents, :summary_generated_at, :datetime
  end
end
