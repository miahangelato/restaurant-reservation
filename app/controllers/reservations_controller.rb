class ReservationsController < ApplicationController
  # Allow guest (anonymous) users to view the reservation creation form, create a reservation,
  # and fetch availability/available tables via AJAX. Other reservation actions still require a logged-in user.
  # Allow guests to view the reservation creation form, create reservations,
  # fetch availability, and view a reservation via token link. Modification actions
  # (edit/update/destroy/cancel) still require a logged-in user.
  before_action :require_login, except: [:new, :create, :available_tables, :availability, :show]
  before_action :set_reservation, only: [:show, :edit, :update, :destroy, :cancel]
  before_action :authorize_reservation, only: [:show, :edit, :update, :destroy, :cancel]
  
  def index
    @upcoming_reservations = current_user.reservations.upcoming
    @past_reservations = current_user.reservations.past
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
      load_availability_data
      flash.now[:alert] = "There was an error creating your reservation."
      render :new, status: :unprocessable_entity
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
  
  def available_tables
    date = Date.parse(params[:date])
    time_slot_id = params[:time_slot_id]
    num_people = params[:num_people].to_i
    # If the requested slot is not at least 2 hours ahead, return no tables
    time_slot = TimeSlot.find_by(id: time_slot_id)
    unless time_slot && at_least_two_hours_ahead?(date, time_slot)
      @available_tables = []
      render partial: 'reservations/table_selection', locals: { available_tables: @available_tables } and return
    end

    @available_tables = Table.by_capacity(num_people)
                              .select { |t| t.available_for_slot?(time_slot_id, date) }
                              .sort_by(&:table_number)
    
    render partial: 'reservations/table_selection', locals: { available_tables: @available_tables }
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
    
    # Load available tables if date and time slot are selected
    if @reservation.reservation_date.present? && @reservation.time_slot_id.present?
      # Prevent loading tables for slots that violate the 2-hour rule
      slot = TimeSlot.find_by(id: @reservation.time_slot_id)
      if slot && at_least_two_hours_ahead?(@reservation.reservation_date, slot)
        load_available_tables
      else
        @available_tables = []
      end
    end
  end
  
  def load_available_tables
    @available_tables = Table.by_capacity(@reservation.num_people || 1)
                              .select { |t| t.available_for_slot?(@reservation.time_slot_id, @reservation.reservation_date) }
                              .sort_by(&:table_number)
  end
  
  def reservation_params
    params.require(:reservation).permit(:time_slot_id, :reservation_date, :num_people, :contact_name, :contact_email, :contact_phone, :table_id)
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
