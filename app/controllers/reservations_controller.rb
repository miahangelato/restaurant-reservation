class ReservationsController < ApplicationController
  # Allow guest (anonymous) users to view the reservation creation form, create a reservation,
  # and fetch availability via AJAX. Other reservation actions still require a logged-in user.
  # Allow guests to view the reservation creation form, create reservations,
  # fetch availability, and view a reservation via token link. Modification actions
  # (edit/update/destroy/cancel) still require a logged-in user.
  before_action :require_login, except: [:new, :create, :availability, :show]
  before_action :set_reservation, only: [:show, :edit, :update, :destroy, :cancel]
  before_action :authorize_reservation, only: [:show, :edit, :update, :destroy, :cancel]
  
  def index
    @upcoming_reservations = current_user.reservations.upcoming.confirmed
    @past_reservations = current_user.reservations.past.confirmed
    # Don't show cancelled reservations at all
  end
  
  def show
    # Expose a guest token to the view only when supplied via the emailed link (params).
    # We intentionally do NOT keep the plain token in the session for management actions
    # because guests are not allowed to edit/cancel — only registered users may perform
    # modification actions. The token is only used to view the reservation when delivered
    # via email.
    @guest_token = params[:guest_token].presence
  end
  
  def new
    @reservation = Reservation.new
    @reservation.reservation_date = params[:date] if params[:date]
    @reservation.time_slot_id = params[:time_slot_id] if params[:time_slot_id]
    load_availability_data
  end
  
  def create
    # Build reservation without assuming a current_user (support guest bookings)
    @reservation = Reservation.new(reservation_params)
    @reservation.user = current_user if current_user.present?
    
    # Validate the reservation first
    if @reservation.valid?
      # Store reservation data in session for confirmation
      session[:pending_reservation] = {
        time_slot_id: @reservation.time_slot_id,
        reservation_date: @reservation.reservation_date,
        num_people: @reservation.num_people,
        contact_name: @reservation.contact_name,
        contact_email: @reservation.contact_email,
        contact_phone: @reservation.contact_phone,
        user_id: current_user&.id
      }
      redirect_to confirm_reservations_path
    else
      load_availability_data
      flash.now[:alert] = "Please correct the errors below."
      render :new, status: :unprocessable_entity
    end
  end
  
  def confirm
    # Load reservation data from session
    pending_data = session[:pending_reservation]
    unless pending_data
      flash[:alert] = "No reservation data found. Please start over."
      redirect_to new_reservation_path
      return
    end
    
    @reservation = Reservation.new(pending_data)
    @reservation.user = current_user if current_user.present?
    @time_slot = TimeSlot.find(@reservation.time_slot_id)
  end
  
  def finalize
    # Load reservation data from session
    pending_data = session[:pending_reservation]
    unless pending_data
      flash[:alert] = "No reservation data found. Please start over."
      redirect_to new_reservation_path
      return
    end
    
    # Build reservation without assuming a current_user (support guest bookings)
    @reservation = Reservation.new(pending_data)
    @reservation.user = current_user if current_user.present?
    # If guest, prepare a token so we can include it in the confirmation email.
    guest_token = nil
    if @reservation.user.nil?
      guest_token = @reservation.prepare_guest_token!
    end

    if @reservation.save
      # If this was a guest booking (no user), store the reservation id in session so the
      # guest can view the reservation immediately afterwards and send the tokenized email.
      if @reservation.user.nil?
        session[:guest_reservation_ids] ||= []
        session[:guest_reservation_ids] << @reservation.id unless session[:guest_reservation_ids].include?(@reservation.id)

        # If we prepared a guest token before save, persist the digest/expires_at and send email
        if guest_token.present?
          # The token digest and expiry are already set on the model; persist them
          @reservation.save!(validate: false)
          ReservationMailer.with(reservation: @reservation, guest_token: guest_token).confirmation_email.deliver_later
        else
          # Fallback: send confirmation without token
          ReservationMailer.with(reservation: @reservation).confirmation_email.deliver_later
        end
      end

      # Clear the session data
      session.delete(:pending_reservation)
      
      # For authenticated users, the model callback will enqueue the confirmation email.
      flash[:success] = "Reservation confirmed! We look forward to seeing you on #{@reservation.formatted_date} at #{@reservation.formatted_time}."

      # If this was a guest booking and we generated a guest token, redirect to the
      # tokenized reservation URL so the guest can view it immediately without
      # requiring a separate sign-in step or relying on session fallbacks.
      if @reservation.user.nil? && guest_token.present?
        redirect_to reservation_url(@reservation, guest_token: guest_token)
      else
        redirect_to reservation_path(@reservation)
      end
    else
      flash[:alert] = "There was an error creating your reservation."
      redirect_to confirm_reservations_path
    end
  end
  
  def edit
    unless @reservation.cancellable?
      flash[:alert] = "This reservation cannot be modified."
      redirect_to reservations_path
    end
    load_availability_data
  end
  
  def update
    unless @reservation.cancellable?
      flash[:alert] = "This reservation cannot be modified."
      redirect_to reservations_path
      return
    end
    
    if @reservation.update(reservation_params)
      flash[:success] = "Reservation updated successfully."
      redirect_to reservation_path(@reservation)
    else
      load_availability_data
      flash.now[:alert] = "There was an error updating your reservation."
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    unless @reservation.cancellable?
      cutoff = Rails.application.config.x.reservations.cancellation_cutoff_hours || 1
      flash[:alert] = "This reservation cannot be cancelled. Cancellations must be made at least #{cutoff} hour(s) in advance."
      redirect_to reservations_path
      return
    end
    
    @reservation.update(status: 'cancelled')
    flash[:success] = "Reservation cancelled successfully."
    redirect_to reservations_path
  end

  # New cancel action (PATCH) – preferred over HTTP DELETE for cancel semantics
  def cancel
    unless @reservation.cancellable?
      cutoff = Rails.application.config.x.reservations.cancellation_cutoff_hours || 1
      flash[:alert] = "This reservation cannot be cancelled. Cancellations must be made at least #{cutoff} hour(s) in advance."
      redirect_to reservations_path
      return
    end

    begin
      @reservation.cancel!
      flash[:success] = "Reservation cancelled successfully."

      # Cleanup any guest-related session state for this reservation so tokens/ids
      # don't linger in the user's session after the reservation is cancelled.
      if session[:guest_reservation_ids]
        session[:guest_reservation_ids].delete(@reservation.id)
        session.delete(:guest_reservation_ids) if session[:guest_reservation_ids].blank?
      end

      if session[:guest_reservation_tokens]
        session[:guest_reservation_tokens].reject! { |h| h[:reservation_id].to_i == @reservation.id }
        session.delete(:guest_reservation_tokens) if session[:guest_reservation_tokens].blank?
      end
    rescue => e
      Rails.logger.error("Failed to cancel reservation #{ @reservation.id }: #{e.message }")
      flash[:alert] = "Failed to cancel reservation. Please try again or contact support."
    end

    redirect_to reservations_path
  end
  
  def availability
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @time_slots = TimeSlot.ordered
    
    # Filter time slots based on 2-hour rule for the selected date
    @time_slots = @time_slots.select do |slot|
      at_least_two_hours_ahead?(@date, slot)
    end
    
    @availability = @time_slots.map do |slot|
      # Respect both capacity and the 2-hour advance rule when reporting availability
      time_ok = at_least_two_hours_ahead?(@date, slot)
      capacity_available = slot.available?(@date)

      {
        time_slot: slot,
        available_tables: slot.available_tables_for_date(@date),
        available: capacity_available && time_ok,
        time_ok: time_ok
      }
    end
  end
  
  def calendar
    @current_date = params[:date] ? Date.parse(params[:date]) : Date.today
    @current_month = @current_date.beginning_of_month
    @next_month = @current_month + 1.month
    @prev_month = @current_month - 1.month
    
    @time_slots = TimeSlot.ordered
    @min_date = Date.today
    @max_date = Date.today + 3.months
    
    # Build calendar data for the current month
    @calendar_data = build_calendar_data(@current_month)
  end
  
  private
  
  def set_reservation
    @reservation = Reservation.find(params[:id])
  end
  
  def authorize_reservation
    # Guests are allowed to VIEW a reservation if they either created it in this session
    # or they present a valid guest token from the confirmation email. However, guests
    # are NOT allowed to edit/update/destroy/cancel — those actions are reserved for
    # registered users. We therefore only allow guest access for the `show` action.
    allowed_for_guest = false
    if action_name == 'show'
      allowed_for_guest = @reservation.user.nil? && (
        session[:guest_reservation_ids]&.include?(@reservation.id) ||
        (params[:guest_token].present? && @reservation.valid_guest_token?(params[:guest_token]))
      )
    end

    unless @reservation.user == current_user || current_user&.admin? || allowed_for_guest
      flash[:alert] = "You are not authorized to access this reservation."
      redirect_to reservations_path
    end
  end
  
  def build_calendar_data(month)
    start_date = month.beginning_of_month
    end_date = month.end_of_month
    
    calendar = {}
    
    (start_date..end_date).each do |date|
      availability_for_date = []
      
      @time_slots.each do |slot|
        available_tables = slot.available_tables_for_date(date)
        availability_for_date << {
          time_slot: slot,
          available_tables: available_tables,
          available: available_tables > 0
        }
      end
      
      total_available = availability_for_date.count { |a| a[:available] }
      
      calendar[date] = {
        availability: availability_for_date,
        total_slots: @time_slots.count,
        available_count: total_available,
        has_availability: total_available > 0
      }
    end
    
    calendar
  end
    
  def load_availability_data
    @time_slots = TimeSlot.ordered
    @min_date = Date.today
    @max_date = Date.today + 3.months
    
    # If a specific date is set, filter based on 2-hour rule and create availability data
    if @reservation&.reservation_date.present?
      @time_slot_availability = {}
      
      @time_slots.each do |slot|
        is_future_valid = at_least_two_hours_ahead?(@reservation.reservation_date, slot)
        available_tables = is_future_valid ? slot.available_tables_for_date(@reservation.reservation_date) : 0
        
        @time_slot_availability[slot.id] = {
          slot: slot,
          is_future_valid: is_future_valid,
          available_tables: available_tables,
          is_available: available_tables > 0 && is_future_valid,
          is_fully_booked: available_tables == 0
        }
      end
      
      # Keep all slots for display but filter for selection
      @available_time_slots = @time_slots.select do |slot|
        availability = @time_slot_availability[slot.id]
        availability[:is_available]
      end
    else
      @available_time_slots = @time_slots
    end
  end
  
  def reservation_params
    params.require(:reservation).permit(:time_slot_id, :reservation_date, :num_people, :contact_name, :contact_email, :contact_phone)
  end

  # Returns true if the given date + time_slot is at least 2 hours in the future.
  # Accepts a Date (or parsable string) and either a TimeSlot object or an id.
  def at_least_two_hours_ahead?(date, time_slot)
    return false unless date.present? && time_slot.present?

    # Normalize date to Date object
    date = Date.parse(date.to_s) unless date.is_a?(Date)

    # Resolve time_slot object if an id was passed
    slot = time_slot.is_a?(TimeSlot) ? time_slot : TimeSlot.find_by(id: time_slot)
    return false unless slot && slot.time.present?

    # Build a timezone-aware reservation datetime using the same parsing used in the model
    reservation_time = Time.zone.parse("#{date} #{slot.time}")
    reservation_time >= 2.hours.from_now
  rescue ArgumentError
    false
  end
end
