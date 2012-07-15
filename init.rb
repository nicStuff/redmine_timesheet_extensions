require 'redmine'

# Taken from lib/redmine.rb
if RUBY_VERSION < '1.9'
  require 'faster_csv'
else
  require 'csv'
  FCSV = CSV
end

require 'dispatcher'
Dispatcher.to_prepare :redmine_timesheet_extensions do
  # Needed for the compatibility check
  begin
    require_dependency 'time_entry_activity'
  rescue LoadError
    # TimeEntryActivity is not available
  end
end





# TODO: tradurre stringhe in inglese
Redmine::Plugin.register :redmine_timesheet_extensions do
  name 'Timesheet Extensions Plugin'
  author 'Nicola Baisero'
  description 'Comprende una serie di estensioni per la gestione del tempo impiegato su attività e progetti.'
  version '0.1.0'

  requires_redmine :version_or_higher => '2.0.3'


  # Impostazioni timesheet plugin modificato

  settings :default => {'list_size' => '5', 'precision' => '2'}, :partial => 'settings/timesheet_settings'
  permission :see_project_timesheets, { }, :require => :member

  menu(:top_menu,
      :timesheet,
      {:controller => 'custom_timesheet_controller', :action => 'index'},
      :caption => :timesheet_title,
      :if => Proc.new {
        User.current.allowed_to?(:see_project_timesheets, nil, :global => true) ||
        User.current.allowed_to?(:view_time_entries, nil, :global => true) ||
        User.current.admin?
      })
end




# Hooks (attualmente non ce ne sono)

# Aggiunta comportamento ai modelli esistenti (Patch)
require 'dispatcher'
require 'time_entry_patch'
Dispatcher.to_prepare do
  TimeEntry.send(:include, TimeEntryPatch) unless TimeEntry.included_modules.include?(TimeEntryPatch)
end
