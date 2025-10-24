class CreateReservations < ActiveRecord::Migration[8.0]
  def change
    create_table :reservations do |t|
      t.references :user, null: false, foreign_key: true
      t.references :time_slot, null: false, foreign_key: true
      t.references :table, foreign_key: true
      t.date :reservation_date, null: false
      t.integer :num_people, null: false
      t.string :contact_name, null: false
      t.string :contact_email, null: false
      t.string :contact_phone, null: false
      t.string :status, null: false, default: 'confirmed'

      t.timestamps
    end
    
    add_index :reservations, [:time_slot_id, :reservation_date, :table_id], name: 'index_reservations_on_slot_date_table'
  end
end
