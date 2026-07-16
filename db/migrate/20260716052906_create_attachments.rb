class CreateAttachments < ActiveRecord::Migration[8.1]
  def change
    create_table :attachments do |t|
      t.references :document, null: false, foreign_key: true
      t.string :filename, null: false
      t.string :content_type, null: false
      t.bigint :file_size, null: false
      t.jsonb :metadata, default: {}
      t.string :preview_state, default: 'pending'

      t.timestamps
    end

    add_index :attachments, :content_type
    add_index :attachments, :preview_state
  end
end
