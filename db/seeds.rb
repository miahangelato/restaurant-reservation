# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).

puts "Seeding database..."

# Create Admin User
admin = User.find_or_create_by!(email: "admin@restaurant.com") do |user|
  user.name = "Admin User"
  user.phone = "+1 234 567 8900"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "admin"
end
puts "✅ Admin user created: #{admin.email}"

# Create Test Customer
customer = User.find_or_create_by!(email: "customer@test.com") do |user|
  user.name = "John Doe"
  user.phone = "+1 234 567 8901"
  user.password = "password123"
  user.password_confirmation = "password123"
  user.role = "customer"
end
puts "✅ Customer user created: #{customer.email}"

# Create additional test customers
3.times do |i|
  User.find_or_create_by!(email: "customer#{i + 1}@test.com") do |user|
    user.name = "Customer #{i + 1}"
    user.phone = "+1 234 567 #{8902 + i}"
    user.password = "password123"
    user.password_confirmation = "password123"
    user.role = "customer"
  end
end
puts "✅ Additional customers created"

# Create Time Slots (hourly from 11 AM to 9 PM)
time_slots_data = [
  { time: "11:00", max_tables: 10, max_people_per_table: 6 },
  { time: "12:00", max_tables: 10, max_people_per_table: 6 },
  { time: "13:00", max_tables: 10, max_people_per_table: 6 },
  { time: "14:00", max_tables: 8, max_people_per_table: 6 },
  { time: "15:00", max_tables: 8, max_people_per_table: 6 },
  { time: "16:00", max_tables: 8, max_people_per_table: 6 },
  { time: "17:00", max_tables: 12, max_people_per_table: 6 },
  { time: "18:00", max_tables: 12, max_people_per_table: 6 },
  { time: "19:00", max_tables: 12, max_people_per_table: 6 },
  { time: "20:00", max_tables: 10, max_people_per_table: 6 },
  { time: "21:00", max_tables: 10, max_people_per_table: 6 }
]

time_slots_data.each do |slot_data|
  TimeSlot.find_or_create_by!(time: slot_data[:time]) do |slot|
    slot.max_tables = slot_data[:max_tables]
    slot.max_people_per_table = slot_data[:max_people_per_table]
  end
end
puts "✅ Time slots created (11 AM - 9 PM)"

# Create Tables
15.times do |i|
  table_number = (i + 1).to_s
  capacity = case i % 4
             when 0 then 2  # Small tables
             when 1 then 4  # Medium tables
             when 2 then 6  # Large tables
             else 8         # Extra large tables
             end
  
  Table.find_or_create_by!(table_number: table_number) do |table|
    table.capacity = capacity
  end
end
puts "✅ 15 tables created"

# Create some sample reservations for testing
time_slots = TimeSlot.all
customers = User.customers

# Create reservations for today and next few days
3.times do |day_offset|
  date = Date.today + day_offset.days
  
  # Only create reservations if date is not in the past and at least 2 hours from now
  next if date < Date.today
  
  # Create 2-3 random reservations per day
  rand(2..3).times do
    time_slot = time_slots.sample
    customer = customers.sample
    
    # Check if the reservation time is at least 2 hours from now
    reservation_datetime = Time.zone.parse("#{date} #{time_slot.time}")
    next if reservation_datetime < 2.hours.from_now
    
    # Find an available table
    available_table = Table.all.find { |t| t.available_for_slot?(time_slot.id, date) }
    next unless available_table
    
    num_people = rand(2..6)
    
    Reservation.create!(
      user: customer,
      time_slot: time_slot,
      table: available_table,
      reservation_date: date,
      num_people: num_people,
      contact_name: customer.name,
      contact_email: customer.email,
      contact_phone: customer.phone,
      status: 'confirmed'
    )
  end
end
puts "✅ Sample reservations created"

puts "\n🎉 Seeding completed successfully!"
puts "\n📝 Login Credentials:"
puts "━" * 50
puts "Admin Account:"
puts "  Email: admin@restaurant.com"
puts "  Password: password123"
puts ""
puts "Customer Account:"
puts "  Email: customer@test.com"
puts "  Password: password123"
puts "━" * 50
