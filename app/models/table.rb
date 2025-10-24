class Table < ApplicationRecord
  # Associations
  has_many :reservations, dependent: :restrict_with_error
  
  # Validations
  validates :table_number, presence: true, uniqueness: true
  validates :capacity, presence: true, numericality: { greater_than: 0 }
  
  # Scopes
  scope :ordered, -> { order(:table_number) }
  scope :by_capacity, ->(capacity) { where("capacity >= ?", capacity) }
  
  # Methods
  def display_name
    "Table #{table_number} (Capacity: #{capacity})"
  end
  
  def available_for_slot?(time_slot_id, date)
    !reservations.exists?(time_slot_id: time_slot_id, reservation_date: date, status: 'confirmed')
  end
end
