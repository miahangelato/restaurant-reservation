class TimeSlot < ApplicationRecord
  # Associations
  has_many :reservations, dependent: :destroy
  
  # Validations
  validates :time, presence: true, uniqueness: true
  validates :max_tables, presence: true, numericality: { greater_than: 0 }
  validates :max_people_per_table, presence: true, numericality: { greater_than: 0 }
  
  # Scopes
  scope :ordered, -> { order(:time) }
  
  # Methods
  def available_tables_for_date(date, party_size = nil)
    # Get all tables that can accommodate the party size (if specified)
    suitable_tables = party_size ? Table.by_capacity(party_size) : Table.all
    
    # Get reserved table IDs for this date and time slot
    reserved_table_ids = reservations.where(reservation_date: date)
                                   .where(status: ['confirmed', 'pending'])
                                   .pluck(:table_id)
                                   .compact
    
    # Return available tables (not reserved)
    suitable_tables.where.not(id: reserved_table_ids)
  end
  
  def available_tables_count_for_date(date, party_size = nil)
    available_tables_for_date(date, party_size).count
  end
  
  def available?(date, party_size = nil)
    available_tables_count_for_date(date, party_size) > 0
  end
  
  # Method to check if any tables are available for a specific date
  def has_availability?(date)
    available_tables_count_for_date(date) > 0
  end
  
  def formatted_time
    time.strftime("%I:%M %p")
  end
end
