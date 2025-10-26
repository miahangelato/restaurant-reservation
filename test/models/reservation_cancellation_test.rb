require "test_helper"

class ReservationCancellationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @user = User.create!(name: "Cancel Test", email: "cancel@example.com", phone: "0123456789", password: "password", role: "customer")
    @slot = TimeSlot.create!(time: Time.zone.local(2000,1,1,18,0,0), max_tables: 5, max_people_per_table: 6)
    @table = Table.create!(table_number: 99, capacity: 6)
  end

  test "cancellable? respects cancellation_cutoff_hours" do
    travel_to Time.zone.local(2025,10,27,10,0,0) do
      # reservation at 12:30 (2.5 hours ahead) should be cancellable with 1-hour cutoff
      r = Reservation.create!(user: @user, time_slot: @slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: "Cancel Test", contact_email: "cancel@example.com", contact_phone: "0123456789")
      assert r.cancellable?

      # reservation less than cutoff (30 minutes ahead) should not be cancellable
      # simulate by setting reservation_date/time to 10:20 same day + slot.time override
      # we approximate by stubbing reservation_datetime using travel_to and a near time slot
      near = Reservation.new(user: @user, time_slot: @slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: "Cancel Test", contact_email: "cancel@example.com", contact_phone: "0123456789")
      # manually set reservation_date/time to 10:30 (within cutoff)
      def near.reservation_datetime; Time.zone.local(2025,10,27,10,30,0); end
      assert_not near.cancellable?
    end
  end

  test "cancel! sets status and cancelled_at" do
    travel_to Time.zone.local(2025,10,27,8,0,0) do
      r = Reservation.create!(user: @user, time_slot: @slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: "Cancel Test", contact_email: "cancel@example.com", contact_phone: "0123456789")
      assert r.cancellable?
      r.cancel!
      r.reload
      assert_equal 'cancelled', r.status
      if r.respond_to?(:cancelled_at)
        assert_not_nil r.cancelled_at
      end
    end
  end
end
