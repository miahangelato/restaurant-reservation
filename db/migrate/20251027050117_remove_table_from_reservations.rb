class RemoveTableFromReservations < ActiveRecord::Migration[8.0]
  def change
    remove_reference :reservations, :table, foreign_key: true
  end
end
