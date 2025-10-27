class Reservation < ApplicationRecord
  # Associations
  # Allow reservations to be created by guest (anonymous) users; user is optional
  belongs_to :user, optional: true
  belongs_to :time_slot
  belongs_to :table, optional: true
  
  # Validations
  validates :reservation_date, presence: true
  validates :num_people, presence: true, numericality: { greater_than: 0 }
  validates :contact_name, presence: true
  validates :contact_email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :contact_phone, presence: true
  validates :status, presence: true, inclusion: { in: %w[pending confirmed cancelled] }
  validates :table_id, presence: true, if: :table_selection_required?
  validate :reservation_date_cannot_be_in_past
  validate :reservation_must_be_at_least_2_hours_in_advance
  validate :num_people_within_time_slot_limit
  validate :table_can_accommodate_party_size
  validate :table_is_available_for_slot
  
  # Callbacks
  before_validation :set_default_contact_info, on: :create
  after_initialize :set_default_status, if: :new_record?
  after_commit :send_confirmation_email, on: :create
  
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
    return false unless status == 'confirmed'

    cutoff_hours = Rails.application.config.x.reservations.cancellation_cutoff_hours || 1
    reservation_datetime >= cutoff_hours.hours.from_now
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

  # Cancel this reservation (sets status and records cancelled_at if present)
  def cancel!
    # Use direct column update to avoid running validations that check table availability
    # (the DB still contains a confirmed row for this reservation until we persist, so
    # validating against the DB would incorrectly block cancellation). This is atomic.
    attrs = { status: 'cancelled' }
    attrs[:cancelled_at] = Time.zone.now if respond_to?(:cancelled_at)
      update_columns(attrs)

      # Enqueue cancellation email after marking cancelled; do not rely on callbacks as we used update_columns
      begin
        ReservationMailer.with(reservation: self).cancellation_email.deliver_later
      rescue => e
        Rails.logger.error("Failed to enqueue cancellation email for reservation #{id}: #{e.message}")
      end
  end

  # Enqueue confirmation email after the reservation is committed
  def send_confirmation_email
    # For authenticated users we can send immediately (no guest token required).
    # Guest reservations with a token are handled explicitly in controller to include the plain token in the email.
    return if user.nil?

    recipient = contact_email.presence || user&.email
    return unless recipient.present?

    ReservationMailer.with(reservation: self).confirmation_email.deliver_later
  end

  # Prepare a guest access token and store its digest and expiry on the reservation record.
  # Returns the plain token (to be sent via email). This method does not save the record.
  def prepare_guest_token!(expiry_days: nil)
    return nil unless user.nil?

    expiry_days ||= Rails.application.config.x.reservations.guest_token_expiry_days || 30
    token = SecureRandom.urlsafe_base64(32)
    digest = Digest::SHA256.hexdigest(token)

    self.guest_token_digest = digest
    self.guest_token_expires_at = Time.zone.now + expiry_days.days

    token
  end

  # Verify a plain guest token against the stored digest and expiry
  def valid_guest_token?(token)
    return false if guest_token_digest.blank? || guest_token_expires_at.blank?
    return false if guest_token_expires_at < Time.zone.now
    return false if token.blank?

    Digest::SHA256.hexdigest(token).casecmp(guest_token_digest) == 0
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
  
  def reservation_date_cannot_be_in_past
    if reservation_date.present? && reservation_date < Date.today
      errors.add(:reservation_date, "cannot be in the past")
    end
  end
  
  def reservation_must_be_at_least_2_hours_in_advance
    if reservation_date.present? && time_slot.present?
      required_hours = Rails.application.config.x.reservations.creation_advance_hours || 2
      if reservation_datetime < required_hours.hours.from_now
        errors.add(:base, "Reservations must be made at least #{required_hours} hours in advance")
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
  
  def table_can_accommodate_party_size
    if table.present? && num_people.present?
      if num_people > table.capacity
        errors.add(:table_id, "cannot accommodate #{num_people} people (capacity: #{table.capacity})")
      end
    end
  end
  
  def table_is_available_for_slot
    if table.present? && time_slot.present? && reservation_date.present?
      # Skip validation if this is the same reservation being updated
      return if persisted? && table_id_was == table_id
      
      unless table.available_for_slot?(time_slot_id, reservation_date)
        errors.add(:table_id, "is already reserved for this time slot")
      end
    end
  end
  
  def table_selection_required?
    # Require table selection for new reservations with complete date/time info
    !persisted? && reservation_date.present? && time_slot_id.present?
  end
end
