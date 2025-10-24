class Admin::TimeSlotsController < Admin::BaseController
  before_action :set_time_slot, only: [:show, :edit, :update, :destroy]
  
  def index
    @time_slots = TimeSlot.ordered
  end
  
  def show
  end
  
  def new
    @time_slot = TimeSlot.new
  end
  
  def create
    @time_slot = TimeSlot.new(time_slot_params)
    
    if @time_slot.save
      flash[:success] = "Time slot created successfully."
      redirect_to admin_time_slots_path
    else
      flash.now[:alert] = "There was an error creating the time slot."
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @time_slot.update(time_slot_params)
      flash[:success] = "Time slot updated successfully."
      redirect_to admin_time_slots_path
    else
      flash.now[:alert] = "There was an error updating the time slot."
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @time_slot.reservations.confirmed.exists?
      flash[:alert] = "Cannot delete time slot with confirmed reservations."
      redirect_to admin_time_slots_path
    else
      @time_slot.destroy
      flash[:success] = "Time slot deleted successfully."
      redirect_to admin_time_slots_path
    end
  end
  
  private
  
  def set_time_slot
    @time_slot = TimeSlot.find(params[:id])
  end
  
  def time_slot_params
    params.require(:time_slot).permit(:time, :max_tables, :max_people_per_table)
  end
end
