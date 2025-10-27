#!/usr/bin/env ruby

puts 'Checking reservations for slot 1 on 2025-10-29...'
reservations = Reservation.where(time_slot_id: 1, reservation_date: '2025-10-29')

puts 'All reservations:'
reservations.each do |r|
  puts "  ID #{r.id}, Status: #{r.status}"
end
puts

active_reservations = reservations.where.not(status: 'cancelled')
puts 'Active (non-cancelled) reservations:'
active_reservations.each do |r|
  puts "  ID #{r.id}, Status: #{r.status}"
end
puts "Count: #{active_reservations.count}"
puts

# Test TimeSlot availability calculation
slot = TimeSlot.find(1)
puts "TimeSlot.available_tables_for_date calculation:"
puts "  Slot 1 for 2025-10-29: #{slot.available_tables_for_date(Date.parse('2025-10-29'))}"

# Check if validation is working correctly
puts
puts "Testing model validation (should work since cancelled reservations don't count):"
test_reservation = Reservation.new(
  time_slot_id: 1, 
  reservation_date: '2025-10-29', 
  num_people: 2, 
  contact_name: 'Test User', 
  contact_email: 'test@example.com', 
  contact_phone: '123-456-7890'
)

if test_reservation.valid?
  puts "SUCCESS: Validation passed - can create reservation"
else
  puts "FAILED: Validation errors:"
  test_reservation.errors.each do |error|
    puts "  - #{error.attribute}: #{error.message}"
  end
end