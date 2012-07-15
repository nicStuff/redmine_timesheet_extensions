RedmineApp::Application.routes.draw do
  match 'custom_timesheet_controller' => 'custom_timesheets#index'
  match 'custom_timesheet/report(.:format)' => 'custom_timesheets#report'
  match 'custom_timesheet/reset' => 'custom_timesheets#reset', :via => :delete
  match 'custom_timesheet/context_menu' => 'custom_timesheets#context_menu'
end