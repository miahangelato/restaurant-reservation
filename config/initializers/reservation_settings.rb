# Reservation related settings
# Use Rails.application.config.x.reservations to access these values
Rails.application.config.x.reservations = ActiveSupport::OrderedOptions.new

# Hours required to create a reservation in advance (default: 2 hours)
Rails.application.config.x.reservations.creation_advance_hours = 2

# Hours before reservation after which cancellations are disallowed (default: 1 hour)
Rails.application.config.x.reservations.cancellation_cutoff_hours = 1
