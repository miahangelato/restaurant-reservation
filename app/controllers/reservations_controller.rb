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
  
  def reservation_params
    params.require(:reservation).permit(:time_slot_id, :reservation_date, :num_people, :contact_name, :contact_email, :contact_phone)
  end
  
  def load_availability_data
    @time_slots = TimeSlot.ordered
    @min_date = Date.today
    @max_date = Date.today + 3.months
  end
end
