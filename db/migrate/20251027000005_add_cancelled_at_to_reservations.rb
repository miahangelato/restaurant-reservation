class AddCancelledAtToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :cancelled_at, :datetime
    add_index :reservations, :cancelled_at
  end
end
