class ChangeReservationStatusDefaultToPending < ActiveRecord::Migration[8.0]
  def change
    change_column_default :reservations, :status, from: 'confirmed', to: 'pending'
  end
end
