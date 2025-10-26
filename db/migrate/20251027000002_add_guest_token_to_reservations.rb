class AddGuestTokenToReservations < ActiveRecord::Migration[8.0]
  def change
    add_column :reservations, :guest_token_digest, :string
    add_column :reservations, :guest_token_expires_at, :datetime
    add_index :reservations, :guest_token_digest
  end
end
