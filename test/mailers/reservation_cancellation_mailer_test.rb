require "test_helper"

class ReservationCancellationMailerTest < ActionMailer::TestCase
  test "cancellation_email is deliverable and contains details" do
    user = User.create!(name: "Cancel Mail Test", email: "cancelmail@example.com", phone: "0123456789", password: "password", role: "customer")
    slot = TimeSlot.create!(time: Time.zone.local(2000,1,1,19,0,0), max_tables: 5, max_people_per_table: 6)
    reservation = Reservation.create!(user: user, time_slot: slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: user.name, contact_email: user.email, contact_phone: user.phone)

    # simulate cancellation
    reservation.cancel!

    email = ReservationMailer.with(reservation: reservation).cancellation_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [reservation.contact_email], email.to
    assert_includes email.subject, "cancelled"
    body_text = email.html_part ? email.html_part.body.to_s : email.body.to_s
    assert_match reservation.formatted_date, body_text
  end
end
