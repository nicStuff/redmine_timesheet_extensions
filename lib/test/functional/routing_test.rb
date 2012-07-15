require File.expand_path('../../test_helper', __FILE__)

class RoutingTest < ActionController::TestCase
  test "route to index" do
    assert_routing 'custom_timesheet_controller', { :controller => "custom_timesheets", :action => "index" }
  end
  test "route to report with format" do
    assert_routing 'custom_timesheet/report.csv', { :controller => "custom_timesheets", :action => 'report', :format => 'csv' }
  end
  test "route to report" do
    assert_routing 'custom_timesheet/report', { :controller => "custom_timesheets", :action => 'report' }
  end

  test "generates report with format" do
    assert_generates 'custom_timesheet/report.csv', {:controller => "custom_timesheets", :action => "report", :format => 'csv'}
  end
  test "generates report" do
    assert_generates 'custom_timesheet/report', {:controller => "custom_timesheets", :action => "report"}
  end




  test "recognizes timelog edit" do
    #  edit_time_entry GET;;;/time_entries/:id/edit(.:format);;;timelog#edit
#    assert_recognizes({ :controller => "timelog", :action => "edit", :id => "1", :project_id => nil }, "/time_entries/1/edit")
    assert_routing({:path => 'time_entries', :method => :get}, { :controller => "timelog", :action => "edit", :id => "1", :project_id => nil })
  end
end