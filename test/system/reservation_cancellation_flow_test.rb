require "application_system_test_case"

class ReservationCancellationFlowTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers
  include ActiveJob::TestHelper

  test "cancelling a reservation from the UI enqueues a cancellation email" do
    travel_to Time.zone.local(2025,10,27,9,0,0) do
      # Sign up through the UI
      visit signup_path
      fill_in "Full Name", with: "Cancel Flow User"
      fill_in "Email Address", with: "cancelflow@example.com"
      fill_in "Phone Number", with: "0123456789"
      fill_in "Password", with: "password"
      fill_in "Confirm Password", with: "password"
      click_on "Create Account"

      assert_current_path reservations_path

      # Prepare time slot and table
      slot = TimeSlot.create!(time: Time.zone.local(2000,1,1,19,0,0), max_tables: 5, max_people_per_table: 6)
      Table.create!(table_number: 42, capacity: 4)

      # Create a reservation directly for the signed-in user
      user = User.find_by(email: 'cancelflow@example.com')
      reservation = Reservation.create!(user: user, time_slot: slot, reservation_date: Date.parse("2025-10-27"), num_people: 2, contact_name: user.name, contact_email: user.email, contact_phone: user.phone)

      visit reservations_path

      # Cancel via UI and assert the cancellation email job is enqueued
      assert_selector 'div.reservation-card', text: reservation.formatted_date

      before_count = ActiveJob::Base.queue_adapter.enqueued_jobs.size

      accept_confirm do
        # Find the reservation card by the 'View Details' link (which points to reservation_path)
        card = find(:xpath, "//a[@href='#{reservation_path(reservation)}']/ancestor::div[contains(@class,'reservation-card')]")
        within(card) do
          click_on 'Cancel Reservation'
        end
      end

      # Wait for the job to be enqueued (server runs in another thread)
      Timeout.timeout(5) do
        loop do
          break if ActiveJob::Base.queue_adapter.enqueued_jobs.size > before_count
          sleep 0.1
        end
      end

      # Expect a success flash and reservation status updated
      assert_text "Reservation cancelled successfully"
      reservation.reload
      assert_equal 'cancelled', reservation.status
    end
  end
end
