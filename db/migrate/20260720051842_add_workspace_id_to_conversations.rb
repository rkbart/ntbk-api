class AddWorkspaceIdToConversations < ActiveRecord::Migration[8.1]
  def change
    add_reference :conversations, :workspace, null: true, foreign_key: true
  end
end
