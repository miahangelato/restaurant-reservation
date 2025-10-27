#!/usr/bin/env ruby

puts 'Testing unique constraint and concurrent booking prevention...'
puts

puts 'Current reservations:'
Reservation.all.each do |r|
  puts "  ID #{r.id}: Slot #{r.time_slot_id}, Date #{r.reservation_date}, Status #{r.status}"
end
puts

puts 'Trying to create a new reservation for slot 1 on 2025-10-29...'
begin
  r = Reservation.create!(
    time_slot_id: 1, 
    reservation_date: '2025-10-29', 
    num_people: 2, 
    contact_name: 'Test User 1', 
    contact_email: 'test1@example.com', 
    contact_phone: '123-456-7890'
  )
  puts "SUCCESS: Created first reservation ID #{r.id}"
rescue => e
  puts "ERROR: #{e.message}"
end

puts
puts 'Now trying to create a duplicate reservation for the same slot and date...'
begin
  r2 = Reservation.create!(
    time_slot_id: 1, 
    reservation_date: '2025-10-29', 
    num_people: 4, 
    contact_name: 'Test User 2', 
    contact_email: 'test2@example.com', 
    contact_phone: '123-456-7891'
  )
  puts "ERROR: Duplicate was allowed! Created reservation ID #{r2.id}"
rescue => e
  puts "SUCCESS: Duplicate was prevented - #{e.message}"
end

puts
puts 'Testing TimeSlot availability calculation:'
slot = TimeSlot.find(1)
availability_oct_29 = slot.available_tables_for_date(Date.parse('2025-10-29'))
puts "Slot 1 availability for 2025-10-29: #{availability_oct_29}"

availability_oct_30 = slot.available_tables_for_date(Date.parse('2025-10-30'))
puts "Slot 1 availability for 2025-10-30: #{availability_oct_30}"