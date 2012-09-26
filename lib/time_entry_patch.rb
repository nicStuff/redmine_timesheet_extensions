=begin
  Aggiungo al modello TimeEntry le funzionalità necessarie a salvare,
  restituire e validare l'ora di inizio.
=end
require_dependency 'time_entry'

module TimeEntryPatch
  def self.included(base)
    base.extend ClassMethods
    base.send(:include, InstanceMethods)

    # Aggiungo codice alla classe
    base.class_eval do
      attr_accessor :start_minute, :end_hour, :end_minute, :start_hour

      before_validation :get_times
      validate :time_validations
      before_save :set_time_and_duration
      
      validates_numericality_of :billed_hours, :allow_nil => true

      add_custom_self_attributes 'start_hour', 'start_minute', 'end_hour', 'end_minute', 'billed_hours'

      # I getter per l'ora di inizio devo metterli per forza qui, né nel modulo
      # TimeEntryPatch né nel modulo InstanceMethods funzionano correttamente,
      # nemmeno con il modificatore public.
      # getter per orari
      def start_hour
        return @start_hour unless @start_hour.blank?
        return start_time.hour unless start_time.blank?
      end

      def start_minute
        return @start_minute unless @start_minute.blank?
        return start_time.min unless start_time.blank?
      end

    end
  end
  
  
  
  module InstanceMethods
    private

    def time_validations
      #logger.info "time_validations\tvalori appena inseriti\tValori pre-esistenti
      #                           \n\tore di inizio e fine: #{@start_hour}:#{@start_minute}--#{@end_hour}:#{@end_minute}\t#{start_hour}:#{start_minute}--#{end_hour}:#{end_minute}
      #                           \n\tOre: #{@hours}\t#{hours}"

      if @start_hour.blank? || @start_minute.blank?
        errors.add :start_hour, :empty
      end

      if hours.blank?
        if @end_hour.blank? || @end_minute.blank?
          errors.add :end_hour, l(:error_et_mandatory_ifnot_hours)
        else
          if @end_time <= @begin_time
            errors.add_to_base l(:error_et_less_than_st)
          end
        end
      else
        if (@end_hour.blank? || @end_minute.blank?) || @end_time <= @begin_time
          if hours <= 0.0
            errors.add :hours, l(:error_h_mb_grthan_zero)
            if @end_time <= @begin_time
              errors.add_to_base l(:error_et_less_than_st)
            end
          else
            if @last_time - @begin_time < float_hours_to_minutes(hours)
              errors.add :hours, "superano la giornata"
              if @end_time <= @begin_time
                errors.add_to_base l(:error_et_less_than_st)
              end
            end
          end
        end
      end
    end

    def set_time_and_duration
      #logger.info "set_time_and_duration"
      self.start_time = Time.local spent_on.year, spent_on.month, spent_on.day, start_hour, start_minute, 0

      if !@end_hour.blank? && !@end_minute.blank? && @end_time > @begin_time
        logger.info "Start & end time: " + @begin_time.to_s + " " + @end_time.to_s
        logger.info "Data start: " + start_time.to_s

        self.hours = minutes_to_float_hours @end_time - @begin_time
      end
      #logger.info "set_time_and_diration finito"
    end

    def get_times
      @begin_time = @start_hour.to_i * 60 + @start_minute.to_i
      @end_time = (@end_hour.to_i * 60 + @end_minute.to_i) || 0
      @last_time = 23 * 60 + 55
      #logger.info "get_times, intervallo: #{@begin_time}--#{@end_time}. Ultima ora: #{@last_time}"
    end

    def float_hours_to_minutes(hrs)
      #tim = Integer((hrs * 60).truncate)
      #logger.info "float_hours_to_minutes, float hours: #{hrs.to_s}, mins: " + tim.to_s
      Integer((hrs * 60).truncate)
    end

    def minutes_to_float_hours(mins)
      #logger.info "ore: " + (Float(mins) / 60).truncate.to_s + "; minuti: #{Float(mins % 60) / 60}"
      (Float(mins) / 60)
    end
  end

  module ClassMethods
    def add_custom_self_attributes(*args)
      args.each {|arg| safe_attributes[0][0] << arg}
    end
  end
end
