require "test_helper"

class ReservationAdvanceValidationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  test "reservation must be made at least 2 hours in advance" do
    # Freeze time so assertions are deterministic
    travel_to Time.zone.local(2025, 10, 27, 10, 0, 0) do
      user = User.create!(name: "Advance Test", email: "advance@example.com", phone: "0123456789", password: "password", role: "customer")

      # Time slot 1 hour ahead -> should be invalid
      slot_soon = TimeSlot.create!(time: Time.zone.local(2000, 1, 1, 11, 0, 0), max_tables: 1, max_people_per_table: 4)
      reservation_soon = Reservation.new(
        user: user,
        time_slot: slot_soon,
        reservation_date: Date.parse("2025-10-27"),
        num_people: 2,
        contact_name: "Advance Test",
        contact_email: "a@example.com",
        contact_phone: "0123456789"
      )

      assert_not reservation_soon.valid?, "Reservation within 2 hours should be invalid"
      assert_includes reservation_soon.errors[:base], "Reservations must be made at least 2 hours in advance"

      # Time slot 3 hours ahead -> should be valid
      slot_ok = TimeSlot.create!(time: Time.zone.local(2000, 1, 1, 13, 0, 0), max_tables: 1, max_people_per_table: 4)
      reservation_ok = Reservation.new(
        user: user,
        time_slot: slot_ok,
        reservation_date: Date.parse("2025-10-27"),
        num_people: 2,
        contact_name: "Advance Test",
        contact_email: "b@example.com",
        contact_phone: "0123456789"
      )

      assert reservation_ok.valid?, "Reservation at least 2 hours ahead should be valid"
    end
  end
end
