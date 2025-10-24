class Admin::TablesController < Admin::BaseController
  before_action :set_table, only: [:show, :edit, :update, :destroy]
  
  def index
    @tables = Table.ordered
  end
  
  def show
  end
  
  def new
    @table = Table.new
  end
  
  def create
    @table = Table.new(table_params)
    
    if @table.save
      flash[:success] = "Table created successfully."
      redirect_to admin_tables_path
    else
      flash.now[:alert] = "There was an error creating the table."
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
  end
  
  def update
    if @table.update(table_params)
      flash[:success] = "Table updated successfully."
      redirect_to admin_tables_path
    else
      flash.now[:alert] = "There was an error updating the table."
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @table.reservations.confirmed.exists?
      flash[:alert] = "Cannot delete table with confirmed reservations."
      redirect_to admin_tables_path
    else
      @table.destroy
      flash[:success] = "Table deleted successfully."
      redirect_to admin_tables_path
    end
  end
  
  private
  
  def set_table
    @table = Table.find(params[:id])
  end
  
  def table_params
    params.require(:table).permit(:table_number, :capacity)
  end
end
