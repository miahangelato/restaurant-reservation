class CreateTables < ActiveRecord::Migration[8.0]
  def change
    create_table :tables do |t|
      t.string :table_number, null: false
      t.integer :capacity, null: false, default: 4

      t.timestamps
    end
    
    add_index :tables, :table_number, unique: true
  end
end
