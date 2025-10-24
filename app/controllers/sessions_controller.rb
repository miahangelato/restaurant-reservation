class SessionsController < ApplicationController
  before_action :require_logout, only: [:new, :create]
  
  def new
    # Login form
  end
  
  def create
    user = User.find_by(email: params[:email].downcase)
    
    if user && user.authenticate(params[:password])
      session[:user_id] = user.id
      flash[:success] = "Welcome back, #{user.name}!"
      
      if user.admin?
        redirect_to admin_dashboard_path
      else
        redirect_to reservations_path
      end
    else
      flash.now[:alert] = "Invalid email or password"
      render :new, status: :unprocessable_entity
    end
  end
  
  def destroy
    session[:user_id] = nil
    flash[:success] = "You have been logged out successfully."
    redirect_to root_path
  end
end
