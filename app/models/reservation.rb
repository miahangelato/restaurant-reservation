class Reservation < ApplicationRecord
  # Associations
  belongs_to :user
  belongs_to :time_slot
  belongs_to :table, optional: true
  
  # Validations
  validates :reservation_date, presence: true
  validates :num_people, presence: true, numericality: { greater_than: 0 }
  validates :contact_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_phone, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }
  validate :reservation_date_cannot_be_in_past
  validate :reservation_must_be_at_least_2_hours_in_advance
  validate :num_people_within_time_slot_limit
  validate :table_availability, if: :table_id?
  
  # Callbacks
  before_validation :set_default_contact_info, on: :create
  before_validation :assign_available_table, on: :create
  after_initialize :set_default_status, if: :new_record?
  
  # Scopes
  scope :confirmed, -> { where(status: 'confirmed') }
  scope :pending, -> { where(status: 'pending') }
  scope :cancelled, -> { where(status: 'cancelled') }
  scope :upcoming, -> { where('reservation_date >= ?', Date.today).order(:reservation_date, :time_slot_id) }
  scope :past, -> { where('reservation_date < ?', Date.today).order(reservation_date: :desc) }
  scope :for_date, ->(date) { where(reservation_date: date) }
  scope :for_date_range, ->(start_date, end_date) { where(reservation_date: start_date..end_date) }
  
  # Methods
  def cancellable?
    status == 'confirmed' && reservation_datetime >= 2.hours.from_now
  end
  
  def reservation_datetime
    Time.zone.parse("#{reservation_date} #{time_slot.time}")
  end
  
  def formatted_date
    reservation_date.strftime("%B %d, %Y")
  end
  
  def formatted_time
    time_slot.formatted_time
  end
  
  private
  
  def set_default_status
    self.status ||= 'confirmed'
  end
  
  def set_default_contact_info
    if user.present?
      self.contact_name ||= user.name
      self.contact_email ||= user.email
      self.contact_phone ||= user.phone
    end
  end
  
  def assign_available_table
    return if table_id.present?
    
    available_table = Table.by_capacity(num_people)
                           .find { |t| t.available_for_slot?(time_slot_id, reservation_date) }
    
    self.table = available_table if available_table
  end
  
  def reservation_date_cannot_be_in_past
    if reservation_date.present? && reservation_date < Date.today
      errors.add(:reservation_date, "cannot be in the past")
    end
  end
  
  def reservation_must_be_at_least_2_hours_in_advance
    if reservation_date.present? && time_slot.present?
      if reservation_datetime < 2.hours.from_now
        errors.add(:base, "Reservations must be made at least 2 hours in advance")
      end
    end
  end
  
  def num_people_within_time_slot_limit
    if num_people.present? && time_slot.present?
      if num_people > time_slot.max_people_per_table
        errors.add(:num_people, "cannot exceed #{time_slot.max_people_per_table} people per table")
      end
    end
  end
  
  def table_availability
    if table.present? && !table.available_for_slot?(time_slot_id, reservation_date)
      errors.add(:table, "is not available for this time slot")
    end
  end
end
