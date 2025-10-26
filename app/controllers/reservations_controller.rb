class ReservationsController < ApplicationController
  before_action :require_login
  before_action :set_reservation, only: [:show, :edit, :update, :destroy]
  before_action :authorize_reservation, only: [:show, :edit, :update, :destroy]
  
  def index
    @upcoming_reservations = current_user.reservations.upcoming
    @past_reservations = current_user.reservations.past
  end
  
  def show
  end
  
  def new
    @reservation = Reservation.new
    @reservation.reservation_date = params[:date] if params[:date]
    @reservation.time_slot_id = params[:time_slot_id] if params[:time_slot_id]
    load_availability_data
  end
  
  def create
    @reservation = current_user.reservations.build(reservation_params)
    
    if @reservation.save
      flash[:success] = "Reservation confirmed! We look forward to seeing you on #{@reservation.formatted_date} at #{@reservation.formatted_time}."
      redirect_to reservation_path(@reservation)
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
      flash[:alert] = "This reservation cannot be cancelled. Reservations must be cancelled at least 2 hours in advance."
      redirect_to reservations_path
      return
    end
    
    @reservation.update(status: 'cancelled')
    flash[:success] = "Reservation cancelled successfully."
    redirect_to reservations_path
  end
  
  def availability
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @time_slots = TimeSlot.ordered
    
    @availability = @time_slots.map do |slot|
      {
        time_slot: slot,
        available_tables: slot.available_tables_for_date(@date),
        available: slot.available?(@date)
      }
    end
  end
  
  def available_tables
    date = Date.parse(params[:date])
    time_slot_id = params[:time_slot_id]
    num_people = params[:num_people].to_i
    
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
    unless @reservation.user == current_user || current_user.admin?
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
      load_available_tables
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
end
