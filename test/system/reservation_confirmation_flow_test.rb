require "application_system_test_case"

class ReservationConfirmationFlowTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  test "creating a reservation from the UI enqueues a confirmation email" do
    travel_to Time.zone.local(2025,10,27,9,0,0) do
      # Sign up through the UI
      visit signup_path
      fill_in "Full Name", with: "Confirm Flow User"
      fill_in "Email Address", with: "confirmflow@example.com"
      fill_in "Phone Number", with: "0123456789"
      fill_in "Password", with: "password"
      fill_in "Confirm Password", with: "password"
      click_on "Create Account"

      assert_current_path reservations_path

      # Prepare a time slot and a table in DB
      slot = TimeSlot.create!(time: Time.zone.local(2000,1,1,19,0,0), max_tables: 5, max_people_per_table: 6)
      Table.create!(table_number: 99, capacity: 4)

      visit new_reservation_path

      # Fill the reservation form
  # Set the date via JS to avoid HTML5 date quirks in the test browser
  execute_script("document.querySelector('input[name=\"reservation[reservation_date]\"]').value = '2025-10-27';")
  # Trigger a change event so Stimulus picks it up and loads available tables
  execute_script("document.querySelector('input[name=\"reservation[reservation_date]\"]').dispatchEvent(new Event('change'));")

      # Select the time slot by option value (the select uses time_slot id as value)
      select_option = find('select[name="reservation[time_slot_id]"]')
      select_option.find("option[value='#{slot.id}']").select_option

      fill_in "Number of People", with: 2
      fill_in "Full Name", with: "Confirm Flow User"
      fill_in "Email", with: "confirmflow@example.com"
      fill_in "Phone Number", with: "0123456789"

      before_count = ActiveJob::Base.queue_adapter.enqueued_jobs.size

      click_on "Confirm Reservation"

      # Wait for the job to be enqueued (server enqueues in separate thread)
      # Give the server a bit more time to enqueue the mail job (separate thread)
      Timeout.timeout(10) do
        loop do
          break if ActiveJob::Base.queue_adapter.enqueued_jobs.size > before_count
          sleep 0.1
        end
      end

  # Expect success flash and that the reservation exists
  # The show page renders a header "✅ Reservation Confirmed" so assert that text
  assert_text "Reservation Confirmed"
      r = Reservation.where(contact_email: 'confirmflow@example.com').order(created_at: :desc).first
      assert r.present?
      assert_equal 'confirmed', r.status
    end
  end
end
