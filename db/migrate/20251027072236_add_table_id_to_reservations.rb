class AddTableIdToReservations < ActiveRecord::Migration[8.0]
  def change
    add_reference :reservations, :table, null: true, foreign_key: true
  end
end
