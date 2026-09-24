class CreateAdminActivities < ActiveRecord::Migration[8.1]
  def change
    create_table :admin_activities do |t|
      t.references :admin, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.jsonb :details, default: {}, null: false
      t.timestamps
    end
    add_index :admin_activities, :created_at
  end
end
