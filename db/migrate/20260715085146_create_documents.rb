class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.string :title, null: false
      t.text :body
      t.references :workspace, null: false, foreign_key: true
      t.references :folder, foreign_key: true
      t.datetime :archived_at

      t.timestamps
    end

    add_index :documents, [ :workspace_id, :folder_id ]
    add_index :documents, [ :workspace_id, :archived_at ]
  end
end
