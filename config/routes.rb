ActionController::Routing::Routes.draw do |map|

  map.connect '/custom_timesheet_controller', :controller => 'custom_timesheets', :action => 'index'

  map.connect 'custom_timesheet/report.:format', :controller => 'custom_timesheets', :action => 'report'
  map.connect 'custom_timesheet/reset', :controller => 'custom_timesheets', :action => 'reset', :conditions => { :method => :delete }
end