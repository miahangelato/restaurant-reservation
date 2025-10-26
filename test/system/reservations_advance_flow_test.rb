require "application_system_test_case"

class ReservationsAdvanceFlowTest < ApplicationSystemTestCase
  include ActiveSupport::Testing::TimeHelpers

  test "user cannot create a reservation less than 2 hours ahead but can create one later" do
    travel_to Time.zone.local(2025, 10, 27, 10, 0, 0) do
      # Sign up a user through the UI
      visit signup_path
      fill_in "Full Name", with: "System User"
      fill_in "Email Address", with: "system@example.com"
      fill_in "Phone Number", with: "0123456789"
      fill_in "Password", with: "password"
      fill_in "Confirm Password", with: "password"
      click_on "Create Account"

      # Ensure redirected to reservations index
      assert_current_path reservations_path

  # Create two time slots: 11:00 (1 hour ahead) and 13:00 (3 hours ahead)
  slot_11 = TimeSlot.create!(time: Time.zone.local(2000,1,1,11,0,0), max_tables: 5, max_people_per_table: 6)
  slot_13 = TimeSlot.create!(time: Time.zone.local(2000,1,1,13,0,0), max_tables: 5, max_people_per_table: 6)

  # Create a table so the reservation can be assigned automatically by the model
  Table.create!(table_number: 1, capacity: 4)

      # Start a new reservation
      visit new_reservation_path

    # Select today's date via JS (avoids HTML5 date quirks) and trigger change
    execute_script("document.querySelector('input[name=\"reservation[reservation_date]\"]').value = '2025-10-27';")
    execute_script("document.querySelector('input[name=\"reservation[reservation_date]\"]').dispatchEvent(new Event('change'));")

  # Choose 11:00 slot (should be within 2 hours and thus blocked) by selecting the time_slot id
  find('select[name="reservation[time_slot_id]"]').find("option[value='#{slot_11.id}']").select_option
  fill_in "Number of People", with: 2
  # Ensure contact info is present (prefilled by current_user in UI, but set explicitly to be safe)
  fill_in "Full Name", with: "System User"
  fill_in "Email", with: "system@example.com"
  fill_in "Phone Number", with: "0123456789"
  click_on "Confirm Reservation"

      # Expect validation error about 2 hours
      assert_text "Reservations must be made at least 2 hours in advance"

      # Now choose 13:00 slot (3 hours ahead) and submit — select by id to avoid locale issues
      find('select[name="reservation[time_slot_id]"]').find("option[value='#{slot_13.id}']").select_option

      # Fill contact fields again to ensure data is posted
      fill_in "Full Name", with: "System User"
      fill_in "Email", with: "system@example.com"
      fill_in "Phone Number", with: "0123456789"

      click_on "Confirm Reservation"

  # Expect reservation to have been created and confirmed (assert on DB to avoid TURBO/flash timing issues)
  r = Reservation.where(contact_email: 'system@example.com').order(created_at: :desc).first
  assert r.present?, "Expected a reservation to be created for system@example.com"
  assert_equal 'confirmed', r.status
    end
  end
end
