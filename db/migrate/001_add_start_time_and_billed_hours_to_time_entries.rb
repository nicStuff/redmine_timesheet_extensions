class AddStartTimeAndBilledHoursToTimeEntries < ActiveRecord::Migration
  def self.up
    change_table :time_entries do |t|
      t.time :start_time
      t.float :billed_hours
    end
  end

  def self.down
    change_table :time_entries do |t|
      t.remove :start_time
      t.remove :billed_hours
    end
  end
end
