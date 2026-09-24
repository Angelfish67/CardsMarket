class AddAdministrationFlagsToCatalogAndUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :suspended, :boolean, default: false, null: false
    add_column :brainrot_types, :active, :boolean, default: true, null: false
    add_column :packs, :active, :boolean, default: true, null: false
  end
end
