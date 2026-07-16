class CreateMessages < ActiveRecord::Migration[8.1]
  def change
    create_table :messages do |t|
      t.references :conversation, null: false, foreign_key: true
      t.string :role, null: false  # "user", "assistant", "system"
      t.text :content, null: false
      t.jsonb :metadata, default: {}
      t.jsonb :document_references, default: []  # Array of document IDs used in context

      t.timestamps
    end

    add_index :messages, [:conversation_id, :created_at]
  end
end
