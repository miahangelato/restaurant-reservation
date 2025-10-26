require "test_helper"

class ReservationMailerTest < ActionMailer::TestCase
  test "confirmation_email contains reservation details" do
    user = User.create!(name: "Mailer Test", email: "mailer@example.com", phone: "0123456789", password: "password", role: "customer")
    slot = TimeSlot.create!(time: Time.zone.local(2000,1,1,19,0,0), max_tables: 5, max_people_per_table: 6)
    reservation = Reservation.create!(user: user, time_slot: slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: user.name, contact_email: user.email, contact_phone: user.phone)

    email = ReservationMailer.with(reservation: reservation).confirmation_email

    assert_emails 1 do
      email.deliver_now
    end

    assert_equal [reservation.contact_email], email.to
    assert_includes email.subject, "Your reservation"
    body_text = if email.html_part
      email.html_part.body.to_s
    else
      email.body.to_s
    end
    assert_match reservation.formatted_date, body_text
  end
end
