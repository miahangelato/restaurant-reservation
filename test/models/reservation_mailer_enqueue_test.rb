require "test_helper"

class ReservationMailerEnqueueTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "creating a reservation enqueues confirmation email" do
    user = User.create!(name: "Enqueue Test", email: "enqueue@example.com", phone: "0123456789", password: "password", role: "customer")
    slot = TimeSlot.create!(time: Time.zone.local(2000,1,1,20,0,0), max_tables: 5, max_people_per_table: 6)

    assert_enqueued_jobs 1 do
      Reservation.create!(user: user, time_slot: slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: user.name, contact_email: user.email, contact_phone: user.phone)
    end
  end
end
