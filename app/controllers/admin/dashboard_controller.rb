class Admin::DashboardController < Admin::BaseController
  def index
    @today_reservations = Reservation.confirmed.for_date(Date.today).includes(:user, :time_slot, :table)
    @upcoming_reservations = Reservation.confirmed.upcoming.limit(10).includes(:user, :time_slot, :table)
    
    # Statistics
    @total_reservations = Reservation.confirmed.count
    @today_count = @today_reservations.count
    @week_count = Reservation.confirmed.for_date_range(Date.today, Date.today + 7.days).count
    @month_count = Reservation.confirmed.for_date_range(Date.today, Date.today + 30.days).count
    
    # Table statistics
    @total_tables = Table.count
    @available_tables_today = Table.count - @today_reservations.where.not(table_id: nil).distinct.count(:table_id)
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
  
  def time_slots_calendar
    @current_date = params[:date] ? Date.parse(params[:date]) : Date.today
    @current_month = @current_date.beginning_of_month
    @next_month = @current_month + 1.month
    @prev_month = @current_month - 1.month
    
    @time_slots = TimeSlot.ordered
    @min_date = Date.today
    @max_date = Date.today + 3.months
    
    # Build calendar data for the current month
    @calendar_data = build_time_slots_calendar_data(@current_month)
  end
  
  private
  
  def build_time_slots_calendar_data(month)
    start_date = month.beginning_of_month
    end_date = month.end_of_month
    
    calendar = {}
    
    (start_date..end_date).each do |date|
      availability_for_date = []
      
      @time_slots.each do |slot|
        available_tables = slot.available_tables_for_date(date)
        total_tables = Table.count
        occupied_tables = total_tables - available_tables.count
        
        availability_for_date << {
          time_slot: slot,
          available_tables: available_tables,
          available_count: available_tables.count,
          occupied_count: occupied_tables,
          total_tables: total_tables,
          available: available_tables.any?
        }
      end
      
      total_available_slots = availability_for_date.count { |a| a[:available] }
      
      calendar[date] = {
        availability: availability_for_date,
        total_slots: @time_slots.count,
        available_count: total_available_slots,
        has_availability: total_available_slots > 0
      }
    end
    
    calendar
  end
end
