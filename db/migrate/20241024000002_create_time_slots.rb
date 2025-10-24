class CreateTimeSlots < ActiveRecord::Migration[8.0]
  def change
    create_table :time_slots do |t|
      t.time :time, null: false
      t.integer :max_tables, null: false, default: 10
      t.integer :max_people_per_table, null: false, default: 6

      t.timestamps
    end
    
    add_index :time_slots, :time, unique: true
  end
end
