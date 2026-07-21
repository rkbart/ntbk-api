class AddPasswordSetByUserToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :password_set_by_user, :boolean, default: false, null: false
  end
end
