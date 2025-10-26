require "test_helper"

class ReservationsControllerTest < ActionController::TestCase
  tests ReservationsController

  def setup
    @user = User.create!(
      name: "Test User",
      email: "testuser@example.com",
      phone: "555-0100",
      password: "password",
      role: "customer"
    )

    @time_slot = TimeSlot.create!(time: Time.zone.parse("19:00"), max_tables: 10, max_people_per_table: 6)

    @reservation = Reservation.create!(
      user: @user,
      time_slot: @time_slot,
      reservation_date: Date.today + 3,
      num_people: 2,
      contact_name: "Guest",
      contact_email: "guest@example.com",
      contact_phone: "555-0200",
      status: 'confirmed'
    )
  end

  test "cancel action cleans up guest session state" do
    # Simulate a logged-in owner performing a cancel while the session contains
    # leftover guest tracking keys from an earlier guest flow.
    session[:user_id] = @user.id
    session[:guest_reservation_ids] = [@reservation.id]
    session[:guest_reservation_tokens] = [{ reservation_id: @reservation.id, token: "plain-token" }]

    patch :cancel, params: { id: @reservation.id }

    assert_redirected_to reservations_path

    # After cancelling, the controller should remove any guest-related session data
    assert_nil session[:guest_reservation_ids], "guest_reservation_ids should be cleared from session"
    assert_nil session[:guest_reservation_tokens], "guest_reservation_tokens should be cleared from session"
  end
end
