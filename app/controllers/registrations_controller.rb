class RegistrationsController < ApplicationController
  before_action :require_logout, only: [:new, :create]
  
  def new
    @user = User.new
  end
  
  def create
    @user = User.new(user_params)
    @user.role = 'customer' # Default role for registration
    
    if @user.save
      session[:user_id] = @user.id
      flash[:success] = "Welcome, #{@user.name}! Your account has been created successfully."
      redirect_to reservations_path
    else
      flash.now[:alert] = "There was an error creating your account."
      render :new, status: :unprocessable_entity
    end
  end
  
  private
  
  def user_params
    params.require(:user).permit(:email, :password, :password_confirmation, :name, :phone)
  end
end
