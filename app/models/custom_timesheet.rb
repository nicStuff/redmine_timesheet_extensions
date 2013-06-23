# Mantiene l'insieme dei risultati applicando il group by a mano a mano che
# vengono aggiunti
class Grouer
  attr_reader :time_entries

  def initialize(campi_gby)
    @campi = campi_gby
    @time_entries = []
    checks
  end

  def has_field?(nome_campo)
    @campi.include? nome_campo
  end

  # Aggiunge alla lista degli elementi una entry realizzando il group by
  def add_time_entry(entry)
    raise "TimeEntry \"#{entry.inspect}\" non valida" if entry.nil?

    entry.class.class_eval do
      def attributes
        @attributes
      end
    end

    # da attributes estraggo uno hash con le sole chiavi di @campi
    filtered_attributes = {}
    # XXX sostituendo con each_pair riduco la complessita a O(n)
    entry.attributes.each_key { |k| filtered_attributes.store k, entry.attributes.fetch(k) if (has_field?(k)) }

    # visito la lista delle entry alla ricerca di una che sia uguale a quella passata
    equal_entry = nil
    @time_entries.each do |r|
      valori_uguali = true
      @campi.each do |c|
        if (c != 'hours' && c != 'billed_hours')
          if filtered_attributes.fetch(c) != r.attributes.fetch(c)
            valori_uguali = false
            next
          end
        end
      end
      if (valori_uguali)
        equal_entry = r
        next
      end
    end

    # aggiorno la entry presente uguale, se esiste, altrimenti aggiungo questa entry all'insieme
    if equal_entry
      equal_entry.attributes.store('hours', equal_entry.attributes.fetch('hours').to_f + filtered_attributes.fetch('hours').to_f) if has_field? 'hours'
      equal_entry.attributes.store('billed_hours', equal_entry.attributes.fetch('billed_hours').to_f + filtered_attributes.fetch('billed_hours').to_f) if has_field? 'billed_hours'
    else
      # TODO una time_entry contiene anche @user, @project, @activity, @issue: vedere se togliere queste cose quando si castrano gli attributi. sempre nello stesso posto, @attributes_cache può dare problemi?
      dup_entry = entry.dup
      dup_entry.attributes = filtered_attributes.dup
      dup_entry.attributes['id'] = entry.id

      @time_entries.push(dup_entry)
    end
  end

  private

  def checks
    raise "Alla creazione di un oggetto #{self.class} si deve specificare almeno un campo" if !@campi || @campi.compact.size.zero?
  end
end

class CustomTimesheet
	# Campi da visualizzare
  attr_accessor :selected_fields

  # Filtri
  attr_accessor :date_from, :date_to, :projects, :activities, :users, :allowed_projects, :period, :period_type, :month, :year

  # List of time entries
  attr_accessor :time_entries

  # Totali delle ore e delle ore fatturate
  attr_accessor :total_hours, :total_billed_hours

  # Array of TimeEntry ids to fetch
  attr_accessor :potential_time_entry_ids

  # Sort time entries by this field
  attr_accessor :sort

  SortOptions = {
    :project_id => I18n.t(:field_project),
    :id => 'ID',
    :user_id => I18n.t(:field_user),
    :issue_id => I18n.t(:field_issue),
    :comments => I18n.t(:field_comments),
    :activity_id => I18n.t(:field_activity),
    :spent_on => I18n.t(:field_spent_on),
    :tweek => I18n.t(:timesheet_week_of_year),
    :hours => I18n.t(:field_hours),
    :billed_hours => I18n.t(:field_billed_hours)
  }

  ValidPeriodType = {
    :free_period => 0,
    :default => 1,
    :month => 3
  }

  def initialize(options = { })
    initialize_selected_fields options[:selected_fields]

    self.projects = [ ]
    self.potential_time_entry_ids = options[:potential_time_entry_ids] || [ ]
    self.allowed_projects = options[:allowed_projects] || [ ]

    # 'Attività' disponibili
    unless options[:activities].nil?
      self.activities = options[:activities].collect { |a| a.to_i }
    else
      self.activities =  TimeEntryActivity.all.collect { |a| a.id.to_i }
    end

    # 'Utenti' disponibili
    unless options[:users].nil?
      self.users = options[:users].collect { |u| u.to_i }
    else
      self.users = CustomTimesheet.viewable_users.collect {|user| user.id.to_i }
    end

    # opzioni 'Order by'
    if !options[:sort].nil? && options[:sort].respond_to?(:to_sym) && SortOptions.keys.include?(options[:sort].to_sym)
      self.sort = options[:sort].to_sym
    else
      self.sort = :project
    end
    
    self.date_from = options[:date_from] || Date.today.to_s
    self.date_to = options[:date_to] || Date.today.to_s
    
    # 'Periodo'
    if options[:period_type] && ValidPeriodType.values.include?(options[:period_type].to_i)
      self.period_type = options[:period_type].to_i
      if (@period_type == 3)
        @month = l('date.month_names').index(options[:month]) unless options[:month].blank?
        @year = options[:year].to_i unless options[:year].blank?
      end
    else
      self.period_type = ValidPeriodType[:free_period]
    end
    self.period = options[:period] || nil

    month_to_period
  end

  # Inizializza i campi selezionati in modo che siano tutti true all'inizio
  def initialize_selected_fields(sel_fields)
    self.selected_fields = {}

    SortOptions.each_key do |k|
      self.selected_fields.store k, 1
    end
    
    unless (sel_fields.blank?)
      self.selected_fields = sel_fields
    end
  end



  # Recupera le time entry dal database applicando il group by
  def retrieve_time_entries(fields, sort)
    results = []

    # Recupero le time entry a seconda dei permessi che ha l'utente
    if User.current.admin?
      results = fetch_all_time_entries self.users, sort
    elsif self.users.detect { |user_id| user_id == User.current.id }
      results = fetch_all_time_entries User.current.id, sort
    end

    # Faccio il group by e conteggio le ore totali
    g = Grouer.new fields
    
    @total_hours = 0
    @total_billed_hours = 0
    results.each do |t|
      g.add_time_entry t
      @total_hours += t.hours if !t.hours.blank?
      @total_billed_hours += t.billed_hours if !t.billed_hours.blank?
    end
    
    # Completo
    @time_entries = g.time_entries
  end

  def period=(period)
    return if self.period_type == CustomTimesheet::ValidPeriodType[:free_period]
    # Stolen from the TimelogController
    case period.to_s
    when 'today'
      self.date_from = self.date_to = Date.today
    when 'yesterday'
      self.date_from = self.date_to = Date.today - 1
    when 'current_week' # Mon -> Sun
      self.date_from = Date.today - (Date.today.cwday - 1)%7
      self.date_to = self.date_from + 6
    when 'last_week'
      self.date_from = Date.today - 7 - (Date.today.cwday - 1)%7
      self.date_to = self.date_from + 6
    when '7_days'
      self.date_from = Date.today - 7
      self.date_to = Date.today
    when 'current_month'
      self.date_from = Date.civil(Date.today.year, Date.today.month, 1)
      self.date_to = (self.date_from >> 1) - 1
    when 'last_month'
      self.date_from = Date.civil(Date.today.year, Date.today.month, 1) << 1
      self.date_to = (self.date_from >> 1) - 1
    when '30_days'
      self.date_from = Date.today - 30
      self.date_to = Date.today
    when 'current_year'
      self.date_from = Date.civil(Date.today.year, 1, 1)
      self.date_to = Date.civil(Date.today.year, 12, 31)
    when 'all'
      self.date_from = self.date_to = nil
    end
    self
  end

  def to_param
    {
      :projects => projects.collect(&:id),
      :date_from => date_from,
      :date_to => date_to,
      :activities => activities,
      :users => users,
      :sort => sort,
      :selected_fields => selected_fields,
      :total_hours => total_hours,
      :total_billed_hours => total_billed_hours
    }
  end

  def to_csv
    result = FCSV.generate do |csv|
      csv << csv_header

      @time_entries.each do |t|
        csv << time_entry_to_csv(t)
      end
    end

    result
  end

  def self.viewable_users
    User.active.select {|user|
      user.allowed_to?(:log_time, nil, :global => true)
    }
  end


  protected

  def csv_header
    csv_head = []

    csv_head.push('#') if @selected_fields.include?('id')
    csv_head.push(l(:label_date)) if @selected_fields.include?('spent_on')
    csv_head.push(l(:timesheet_week_of_year)) if @selected_fields.include?('tweek')
    csv_head.push(l(:label_member)) if @selected_fields.include?('user_id')
    csv_head.push(l(:label_activity)) if @selected_fields.include?('activity_id')
    csv_head.push(l(:label_project)) if @selected_fields.include?('project_id')
    if @selected_fields.include?('issue_id')
      csv_head.push(l(:label_issue))
      csv_head.push("#{l(:label_issue)} #{l(:field_subject)}")
    end
    csv_head.push(l(:field_comments)) if @selected_fields.include?('comments')
    csv_head.push(l(:field_hours)) if @selected_fields.include?('hours')
    csv_head.push(l(:timesheet_billed_hours)) if @selected_fields.include?('billed_hours')

    return csv_head
  end

  def time_entry_to_csv(time_entry)
    csv_data = []
    
    csv_data.push(time_entry.id) if @selected_fields.include?('id')
    csv_data.push(time_entry.spent_on) if @selected_fields.include?('spent_on')
    csv_data.push(time_entry.tweek) if @selected_fields.include?('tweek')
    csv_data.push(time_entry.user.name) if @selected_fields.include?('user_id')
    csv_data.push(time_entry.activity.name) if @selected_fields.include?('activity_id')
    csv_data.push(time_entry.project.name) if @selected_fields.include?('project_id')
    csv_data.push("#{time_entry.issue.tracker.name} ##{time_entry.issue.id}") if @selected_fields.include?('issue_id') && time_entry.issue
    csv_data.push(time_entry.issue.subject) if @selected_fields.include?('issue_id') && time_entry.issue
    csv_data.push(time_entry.comments) if @selected_fields.include?('comments')
    csv_data.push(time_entry.hours) if @selected_fields.include?('hours')
    csv_data.push(time_entry.billed_hours) if @selected_fields.include?('billed_hours')

    return csv_data
  end

  # Array of users to find
  # String of extra conditions to add onto the query (AND)
  def conditions(users, extra_conditions=nil)
    if self.potential_time_entry_ids.empty?
      if self.date_from.present? && self.date_to.present?
        conditions = ["spent_on >= (:from) AND spent_on <= (:to) AND #{TimeEntry.table_name}.project_id IN (:projects) AND user_id IN (:users) AND (activity_id IN (:activities) OR (#{::Enumeration.table_name}.parent_id IN (:activities) AND #{::Enumeration.table_name}.project_id IN (:projects)))",
                      {
                        :from => self.date_from,
                        :to => self.date_to,
                        :projects => self.projects,
                        :activities => self.activities,
                        :users => users
                      }]
      else # All time
        conditions = ["#{TimeEntry.table_name}.project_id IN (:projects) AND user_id IN (:users) AND (activity_id IN (:activities) OR (#{::Enumeration.table_name}.parent_id IN (:activities) AND #{::Enumeration.table_name}.project_id IN (:projects)))",
                      {
                        :projects => self.projects,
                        :activities => self.activities,
                        :users => users
                      }]
      end
    else
      conditions = ["user_id IN (:users) AND #{TimeEntry.table_name}.id IN (:potential_time_entries)",
                    {
                      :users => users,
                      :potential_time_entries => self.potential_time_entry_ids
                    }]
    end

    if extra_conditions
      conditions[0] = conditions.first + ' AND ' + extra_conditions
    end

    return conditions
  end

  def includes
    includes = [:activity, :user, :project, {:issue => [:tracker, :assigned_to, :priority]}]
    return includes
  end



  private

  # Recupera tutte le time entry
  def fetch_all_time_entries(users, sort)
    return TimeEntry.find(:all,
                :include => self.includes,
                :conditions => self.conditions(users),
                :order => "time_entries.#{sort}, time_entries.spent_on"
              )
  end
  
  # Recupera il mese e l'anno selezionati ed imposta il periodo di inizio e fine
  # come se fosse stato digitato nelle text box
  def month_to_period
    # Procedo se il radio button è selezionato e mese e anno non sono nulli
    if (@period_type == 3)
      if (@year)
        t = Time.new
        t = t.change(:year => @year)

        a = Time.new

        if (@month)
          t = t.change(:month => @month)
          @date_from = t.beginning_of_month.to_formatted_s(:db)
          @date_to = t.end_of_month.to_formatted_s(:db)
        else
          @date_from = t.beginning_of_year.to_formatted_s(:db)
          @date_to = t.end_of_year.to_formatted_s(:db)
        end
      end
    end
  end

  def l(*args)
    I18n.t(*args)
  end
end
