class ChangeReservationStatusDefaultBackToConfirmed < ActiveRecord::Migration[8.0]
  def change
    change_column_default :reservations, :status, from: 'pending', to: 'confirmed'
  end
end
