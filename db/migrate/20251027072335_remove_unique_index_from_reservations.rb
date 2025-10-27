class RemoveUniqueIndexFromReservations < ActiveRecord::Migration[8.0]
  def change
    remove_index :reservations, name: 'index_reservations_on_time_slot_and_date_unique'
  end
end
