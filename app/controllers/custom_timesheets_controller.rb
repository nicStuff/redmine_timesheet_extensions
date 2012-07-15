class CustomTimesheetsController < ApplicationController
  unloadable

  layout 'base'
  before_filter :get_list_size
  before_filter :get_precision
  before_filter :get_activities

  helper :sort
  include SortHelper
  helper :issues
  include ApplicationHelper
  helper :timelog

  SessionKey = 'timesheet_filter'

  def index
    load_filters_from_session
    @timesheet ||= CustomTimesheet.new
    @timesheet.allowed_projects = allowed_projects

    respond_to do |format|
      if @timesheet.allowed_projects.empty?
        format.html { render :action => 'no_projects' }
      else
        format.html
      end
    end
  end

  
  def report
    if params && params[:timesheet]
      @timesheet = CustomTimesheet.new(params[:timesheet])
    else
      redirect_to :action => 'index'
      return
    end

    @timesheet.allowed_projects = allowed_projects

    if @timesheet.allowed_projects.empty?
      render :action => 'no_projects'
      return
    end

    if !params[:timesheet][:projects].blank?
      @timesheet.projects = @timesheet.allowed_projects.find_all { |project|
        params[:timesheet][:projects].include?(project.id.to_s)
      }
    else
      @timesheet.projects = @timesheet.allowed_projects
    end
    
    save_filters_to_session(@timesheet)

    @timesheet.retrieve_time_entries(params[:timesheet][:selected_fields].keys, params[:timesheet][:sort]) unless (params[:timesheet][:selected_fields].blank?)
    
    respond_to do |format|
      format.html
      format.csv { send_data @timesheet.to_csv, :filename => 'timesheet.csv', :type => "text/csv" }
    end
  end


  def context_menu
    @time_entries = TimeEntry.find(:all, :conditions => ['id IN (?)', params[:ids]])
    render :layout => false
  end

  def reset
    clear_filters_from_session
    redirect_to :action => 'index'
  end

  private

  def get_list_size
    # TODO per ora uso una dimensione fissa di default
    @list_size = 5
    @list_size = Setting.plugin_redmine_timesheet_extensions['list_size'].to_i
  end

  def get_precision
    # TODO per ora uso una dimensione fissa
    @precision = 2

    precision = Setting.plugin_redmine_timesheet_extensions['precision']

    if precision.blank?
      # Set precision to a high number
      @precision = 10
    else
      @precision = precision.to_i
    end
  end

  def get_activities
    @activities = TimeEntryActivity.all
  end

  def allowed_projects
    if User.current.admin?
      return Project.find(:all, :order => 'name ASC')
    else
      return Project.find(:all, :conditions => Project.visible_condition(User.current), :order => 'name ASC')
    end
  end

  def clear_filters_from_session
    session[SessionKey] = nil
  end

  def load_filters_from_session
    if session[SessionKey]
      @timesheet = CustomTimesheet.new(session[SessionKey])
      # Default to free period
      @timesheet.period_type = CustomTimesheet::ValidPeriodType[:free_period]
    end

    if session[SessionKey] && session[SessionKey]['projects']
      @timesheet.projects = allowed_projects.find_all { |project|
        session[SessionKey]['projects'].include?(project.id.to_s)
      }
    end
  end

  def save_filters_to_session(timesheet)
    if params[:timesheet]
      session[SessionKey] = params[:timesheet]
    end

    if timesheet
      session[SessionKey]['date_from'] = timesheet.date_from
      session[SessionKey]['date_to'] = timesheet.date_to
    end
  end
end