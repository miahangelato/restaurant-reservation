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
  def available_tables_for_date(date)
    reserved_count = reservations.where(reservation_date: date, status: 'confirmed').count
    max_tables - reserved_count
  end
  
  def available?(date)
    available_tables_for_date(date) > 0
  end
  
  def formatted_time
    time.strftime("%I:%M %p")
  end
end
