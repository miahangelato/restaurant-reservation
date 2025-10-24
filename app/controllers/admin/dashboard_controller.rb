class Admin::DashboardController < Admin::BaseController
  def index
    @today_reservations = Reservation.confirmed.for_date(Date.today).includes(:user, :time_slot, :table)
    @upcoming_reservations = Reservation.confirmed.upcoming.limit(10).includes(:user, :time_slot, :table)
    
    # Statistics
    @total_reservations = Reservation.confirmed.count
    @today_count = @today_reservations.count
    @week_count = Reservation.confirmed.for_date_range(Date.today, Date.today + 7.days).count
    @month_count = Reservation.confirmed.for_date_range(Date.today, Date.today + 30.days).count
  end
  
  def calendar
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    @view = params[:view] || 'daily'
    
    case @view
    when 'daily'
      @reservations = Reservation.confirmed.for_date(@date).includes(:user, :time_slot, :table).order('time_slots.time')
      @time_slots = TimeSlot.ordered
    when 'weekly'
      start_date = @date.beginning_of_week
      end_date = @date.end_of_week
      @reservations = Reservation.confirmed.for_date_range(start_date, end_date).includes(:user, :time_slot, :table)
      @dates = (start_date..end_date).to_a
    when 'monthly'
      start_date = @date.beginning_of_month
      end_date = @date.end_of_month
      @reservations = Reservation.confirmed.for_date_range(start_date, end_date).includes(:user, :time_slot, :table)
      @dates = (start_date..end_date).to_a
    end
  end
end
