class AddRolesAndFamilyIdToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :roles, :string, default: "parent"
    add_column :users, :family_id, :string
  end
end
