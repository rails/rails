# frozen_string_literal: true

module ActiveRecord
  class LogSubscriber < ActiveSupport::LogSubscriber
    IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    def self.runtime=(value)
      ActiveRecord::RuntimeRegistry.sql_runtime = value
    end

    def self.runtime
      ActiveRecord::RuntimeRegistry.sql_runtime ||= 0
    end

    def self.reset_runtime
      rt, self.runtime = runtime, 0
      rt
    end

    def strict_loading_violation(event)
      debug do
        owner = event.payload[:owner]
        association = event.payload[:reflection].klass
        name = event.payload[:reflection].name

        color("Strict loading violation: #{owner} is marked for strict loading. The #{association} association named :#{name} cannot be lazily loaded.", RED)
      end
    end

    def sql(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload

      return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

      name  = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      name  = "CACHE #{name}" if payload[:cached]
      sql   = payload[:sql]
      binds = nil

      if payload[:binds]&.any?
        casted_params = type_casted_binds(payload[:type_casted_binds])

        binds = []
        payload[:binds].each_with_index do |attr, i|
          binds << render_bind(attr, casted_params[i])
        end
        binds = binds.inspect
        binds.prepend("  ")
      end

      name = colorize_payload_name(name, payload[:name])
      sql  = color(sql, sql_color(sql), true) if colorize_logging

      debug "  #{name}  #{sql}#{binds}"
    end

    private
      def type_casted_binds(casted_binds)
        casted_binds.respond_to?(:call) ? casted_binds.call : casted_binds
      end

      def render_bind(attr, value)
        case attr
        when ActiveModel::Attribute
          if attr.type.binary? && attr.value
            value = "<#{attr.value_for_database.to_s.bytesize} bytes of binary data>"
          end
        when Array
          attr = attr.first
        else
          attr = nil
        end

        [attr&.name, value]
      end

      def colorize_payload_name(name, payload_name)
        if payload_name.blank? || payload_name == "SQL" # SQL vs Model Load/Exists
          color(name, MAGENTA, true)
        else
          color(name, CYAN, true)
        end
      end

      def sql_color(sql)
        case sql
        when /\A\s*rollback/mi
          RED
        when /select .*for update/mi, /\A\s*lock/mi
          WHITE
        when /\A\s*select/i
          BLUE
        when /\A\s*insert/i
          GREEN
        when /\A\s*update/i
          YELLOW
        when /\A\s*delete/i
          RED
        when /transaction\s*\Z/i
          CYAN
        else
          MAGENTA
        end
      end

      def logger
        ActiveRecord::Base.logger
      end

      def debug(progname = nil, &block)
        return unless super

        if ActiveRecord::Base.verbose_query_logs
          log_query_source
        end
      end

      def log_query_source
        source = extract_query_source_location(caller)

        if source
          logger.debug("  ↳ #{source}")
        end
      end

      def extract_query_source_location(locations)
        backtrace_cleaner.clean(locations.lazy).first
      end
  end
end

ActiveRecord::LogSubscriber.attach_to :active_record
