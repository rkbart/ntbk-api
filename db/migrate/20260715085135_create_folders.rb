class CreateFolders < ActiveRecord::Migration[8.1]
  def change
    create_table :folders do |t|
      t.string :name, null: false
      t.references :workspace, null: false, foreign_key: true
      t.references :parent, foreign_key: { to_table: :folders }

      t.timestamps
    end

    add_index :folders, [ :workspace_id, :parent_id ]
  end
end
