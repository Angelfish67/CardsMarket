class AddMarketFieldsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :username, :string
    add_column :users, :role, :integer
    add_column :users, :coins, :integer
    add_column :users, :starter_pack_opened_at, :datetime
  end
end
