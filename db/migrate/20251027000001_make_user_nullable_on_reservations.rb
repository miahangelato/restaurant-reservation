class MakeUserNullableOnReservations < ActiveRecord::Migration[8.0]
  def change
    # Allow reservations to be created by anonymous (guest) users by making user_id nullable
    change_column_null :reservations, :user_id, true
  end
end
