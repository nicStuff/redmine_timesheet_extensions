module CustomTimesheetsHelper
  def showing_users(users)
    l(:timesheet_showing_users) + users.collect(&:name).join(', ')
  end

  def permalink_to_timesheet(timesheet)
    link_to(l(:timesheet_permalink),
            :controller => 'custom_timesheets',
            :action => 'report',
            :timesheet => timesheet.to_param)
  end

  def link_to_csv_export(timesheet)
    link_to('CSV',
            {
              :controller => 'custom_timesheets',
              :action => 'report',
              :format => 'csv',
              :timesheet => timesheet.to_param
            },
            :method => 'post',
            :class => 'icon icon-timesheet')
  end

  def toggle_issue_arrows(issue_id)
    js = "toggleTimeEntries('#{issue_id}'); return false;"

    return toggle_issue_arrow(issue_id, 'toggle-arrow-closed.gif', js, false) +
      toggle_issue_arrow(issue_id, 'toggle-arrow-open.gif', js, true)
  end

  def toggle_issue_arrow(issue_id, image, js, hide=false)
    style = "display:none;" if hide
    style ||= ''

    content_tag(:span,
                link_to_function(image_tag(image, :plugin => "redmine_timesheet_extensions"), js),
                :class => "toggle-" + issue_id.to_s,
                :style => style
                )

  end

  def displayed_time_entries_for_issue(time_entries)
    time_entries.collect(&:hours).sum
  end

  def project_options(timesheet)
    available_projects = timesheet.allowed_projects
    selected_projects = timesheet.projects.collect(&:id)
    selected_projects = available_projects.collect(&:id) if selected_projects.blank?

    # Organizzo i progetti in un albero secondo le relazioni padre-figlio
    available_projects = organize_projects_in_hierarchy(available_projects)

    # creo la lista di option, e metto ogni elemento in una stringa
    options = ''

    available_projects.each do |p|
      id = generate_html_id p
      sons = ''
      unless p.descendents.blank?
        p.descendents.each do |d|
          sons += generate_html_id(d) + " "
        end
      end

      spaces = "&nbsp;&nbsp;&nbsp;&nbsp;" * p.nidification_level
      selected = ''
      selected = 'selected=\'selected\'' if selected_projects.include?(p.id)
      
      options += "<option value=\"#{p.id}\" class=\"#{sons}\" id=\"#{id}\" #{selected}>#{spaces}#{p.name}</option>\n"
    end

    # creo la select con la lista di option


    return "<select id='timesheet_projects_' size='#{@list_size}' name='timesheet[projects][]' multiple='multiple'>#{options}</select>"
  end
  
  def activity_options(timesheet, activities)
    options_from_collection_for_select(activities, :id, :name, timesheet.activities)
  end

  def user_options(timesheet)
    available_users = CustomTimesheet.viewable_users.sort { |a,b| a.to_s.downcase <=> b.to_s.downcase }
    selected_users = timesheet.users

    options_from_collection_for_select(available_users,
                                       :id,
                                       :name,
                                       selected_users)

  end



  # Crea una checkbox completa di label per indicare se mostrare il campo
  # nei risultati o no
  def complete_checkbox(field_name, text)
    to_select = @timesheet.selected_fields.include?(field_name)
    @result = '<p>' +
      check_box_tag('timesheet_field_' + field_name.to_s, 1, to_select, :disabled => false, :name =>'timesheet[selected_fields][' + field_name.to_s + ']') +
      label_tag('timesheet_field_' + field_name.to_s, text) +
              '</p>'
    @result
  end

  def table_header(width, label, field)
    header = ''
    header = '<th width="' + width + '%">' + label + '</th>' if @timesheet.selected_fields.has_key?(field)
    header
  end

  def table_col(center, field)
    col = ''
    
    if selected?(field)
      col += '<td'
      col += ' align="center"' if center
      col += '>'
      block_result = yield
      col += block_result.to_s unless block_result.blank?
      col += '</td>'
    end

    col
  end

  def selected?(field_name)
    @timesheet.selected_fields.has_key? field_name
  end

  private



  def generate_html_id(project)
    return 'proflist-' + project.id.to_s
  end


  # Ad ogni option metto l'id che venga asspciato al progetto (tipo
  # 'prolist_<id_progetto>') e nell'attributo class la lista di attributi
  # id dei figli

  
  # Aggiunge ai progetti le informazioni relative alla struttura ad albero
  # (padre, figli...) e riorganizza la lista in modo che siano ordinati
  # correttamente
  def organize_projects_in_hierarchy(projects)
    # Devo mostrare i progetti ad albero così com'è il loro legame di parentela
    # => ordino per nome per fare bello (già fatto)
    # => aggiungo ad ogni oggetto di tipo 'Project' (per capirci ogni elemento
    #    della lista qui in ingresso) le informazioni su:
    #    => a che livello di nidificazione è (0 il padre, 1 il figlio, 2 il figlio del figlio...):
    #       nella vista lo uso per indentare il testo
    #    => a che gruppo di progetti appartiene: serve per fare in modo che, nella vista, quando si seleziona un progetto
    #       vengano selezionati in automatico (con javascript) tutti i sottoprogetti
    # => scandisco i progetti e li ordino in modo che siano messi in ordine di:
    #    => padre-figlio (il padre sta sopra al figlio), alfabetico

    # lista risultato, contiene oggetti Project
    result = []
    # lista di hash con <id progetto padre> => <lista progetti figli>: se un progetto
    # non ha figli non è presente come chiave in uno hash
    connections = {}

    # Con una visita sulla lista dei progetti:
    # => aggiungo ad un progetto i nuovi attributi
    # => riempio la lista di out con i padri (quelli con parent_id pari a null)
    # => creo una lista di hash in cui in ogni hash la chiave è un progetto padre ed il valore la lista di figli (id)
    projects.each do |p|
      # aggiungo ad ogni progetto il numero di padri e di discendenti
      p.instance_eval do
        ghost = class << self; self; end
        ghost.class_eval do
          # nidification_level indica a che livello è il progetto nella discendenza
          # (0 => padre, 1 => figlio, 2 => figlio del figlio...): nella vista serve per sapere
          # quanto indentare il testo
          # descendents è una lista con gli id dei progetti discendenti nella gerarchia e serve nella
          # logica lato client (javascript) per selezionare in automatico
          # i discendenti di un progetto
          attr_accessor :nidification_level, :descendents
        end
      end
      
      if (p.parent_id.blank?)
        # Prendo i padri assoluti e li metto nella lista di uscita
        result << p
        
        # un padre assoluto è primo nella gerarchia
        p.nidification_level = 0
      else
        # il progetto ha un padre
        if connections.has_key?(p.parent_id)
          connections.fetch(p.parent_id) << p
        else
          connections.store(p.parent_id, [p])
        end
      end
    end

    # Adesso inserisco in 'result' tutti i progetti figli, subito dopo ai padri
    # Ogni volta che inserisco i figli nella lista cancello l'hash da
    # 'connections': avanzo finché connections non è vuota

    until connections.empty?
      # indica, di volta in volta, dove inserire i nuovi progetti
      index = 0
      # Per ogni progetto di out prendo la lista dei figli
      result.each do |r|
        index += 1
        sons = connections.fetch(r.id, nil)
        # Vado al prossimo se il figlio non è stato trovato
        next if sons.blank?

        r.descendents = []

        sons_index = index
        sons.each do |s|
          result.insert(sons_index, s)
          sons_index += 1
          s.nidification_level = r.nidification_level + 1
          r.descendents << s
        end
        
        # Tolgo la il dato dallo hash
        connections.delete(r.id)
      end
    end

    result
  end
end
