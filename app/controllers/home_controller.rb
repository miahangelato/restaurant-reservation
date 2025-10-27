class HomeController < ApplicationController
  def index
    if logged_in?
      if current_user.admin?
        redirect_to admin_dashboard_path
      else
        redirect_to reservations_path
      end
    else
      redirect_to login_path
    end
  end
end
