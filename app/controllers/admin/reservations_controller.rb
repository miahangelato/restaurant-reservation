class Admin::ReservationsController < Admin::BaseController
  before_action :set_reservation, only: [:show, :edit, :update, :destroy, :confirm]
  
  def index
    @reservations = Reservation.includes(:user, :time_slot, :table).order(reservation_date: :desc, created_at: :desc)
    
    # Filters
    if params[:status].present?
      @reservations = @reservations.where(status: params[:status])
    end
    
    if params[:date].present?
      @reservations = @reservations.for_date(Date.parse(params[:date]))
    end
    
    if params[:search].present?
      search_term = "%#{params[:search]}%"
      @reservations = @reservations.joins(:user).where(
        "users.name LIKE ? OR users.email LIKE ? OR reservations.contact_name LIKE ? OR reservations.contact_email LIKE ?",
        search_term, search_term, search_term, search_term
      )
    end
    
    @reservations = @reservations.page(params[:page]).per(20) if defined?(Kaminari)
  end
  
  def show
  end
  
  def new
    @reservation = Reservation.new
    load_form_data
  end
  
  def create
    @reservation = Reservation.new(reservation_params)
    
    if @reservation.save
      flash[:success] = "Reservation created successfully."
      redirect_to admin_reservation_path(@reservation)
    else
      load_form_data
      flash.now[:alert] = "There was an error creating the reservation."
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    load_form_data
  end
  
  def update
    if @reservation.update(reservation_params)
      flash[:success] = "Reservation updated successfully."
      redirect_to admin_reservation_path(@reservation)
    else
      load_form_data
      flash.now[:alert] = "There was an error updating the reservation."
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    @reservation.update(status: 'cancelled')
    flash[:success] = "Reservation cancelled successfully."
    redirect_to admin_reservations_path
  end
  
  def confirm
    if @reservation.status == 'pending'
      @reservation.update(status: 'confirmed')
      flash[:success] = "Reservation confirmed successfully."
    else
      flash[:alert] = "Only pending reservations can be confirmed."
    end
    redirect_to admin_reservation_path(@reservation)
  end
  
  private
  
  def set_reservation
    @reservation = Reservation.find(params[:id])
  end
  
  def reservation_params
    params.require(:reservation).permit(:user_id, :time_slot_id, :table_id, :reservation_date, :num_people, :contact_name, :contact_email, :contact_phone, :status)
  end
  
  def load_form_data
    @users = User.customers.order(:name)
    @time_slots = TimeSlot.ordered
    @tables = Table.ordered
  end
end
