class AddUniqueIndexToReservations < ActiveRecord::Migration[8.0]
  def change
    add_index :reservations, [:time_slot_id, :reservation_date], 
              unique: true, 
              name: 'index_reservations_on_time_slot_and_date_unique',
              where: "status != 'cancelled'"
  end
end
