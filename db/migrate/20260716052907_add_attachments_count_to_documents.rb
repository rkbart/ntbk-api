class AddAttachmentsCountToDocuments < ActiveRecord::Migration[8.1]
  def up
    add_column :documents, :attachments_count, :integer, default: 0, null: false
  end

  def down
    remove_column :documents, :attachments_count
  end
end
