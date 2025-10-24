class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern
  
  helper_method :current_user, :logged_in?, :admin_user?
  
  private
  
  def current_user
    @current_user ||= User.find_by(id: session[:user_id]) if session[:user_id]
  end
  
  def logged_in?
    current_user.present?
  end
  
  def admin_user?
    logged_in? && current_user.admin?
  end
  
  def require_login
    unless logged_in?
      flash[:alert] = "You must be logged in to access this page."
      redirect_to login_path
    end
  end
  
  def require_admin
    unless admin_user?
      flash[:alert] = "You must be an administrator to access this page."
      redirect_to root_path
    end
  end
  
  def require_logout
    if logged_in?
      flash[:notice] = "You are already logged in."
      redirect_to root_path
    end
  end
end
