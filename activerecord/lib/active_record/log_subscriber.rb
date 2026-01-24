# frozen_string_literal: true

module ActiveRecord
  class LogSubscriber < ActiveSupport::EventReporter::LogSubscriber # :nodoc:
    IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

    self.namespace = "active_record"

    class_attribute :backtrace_cleaner, default: ActiveSupport::BacktraceCleaner.new

    def strict_loading_violation(event)
      debug do
        owner = event[:payload][:owner]
        klass = event[:payload][:class]
        name = event[:payload][:name]
        message = +"`#{owner}` is marked for strict_loading."
        message << " The #{klass ? "#{klass} association" : "polymorphic association"}"
        message << " named `:#{name}` cannot be lazily loaded."

        color(message, RED)
      end
    end
    event_log_level :strict_loading_violation, :debug

    def sql(event)
      payload = event[:payload]

      return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

      name = if payload[:async]
        "ASYNC #{payload[:name]} (#{payload[:lock_wait].round(1)}ms) (db time #{payload[:duration_ms].round(1)}ms)"
      else
        "#{payload[:name]} (#{payload[:duration_ms].round(1)}ms)"
      end
      name  = "CACHE #{name}" if payload[:cached]
      sql   = payload[:sql]
      binds = payload[:binds]

      if payload[:binds]&.any?
        binds = binds.inspect
        binds.prepend("  ")
      end

      name = colorize_payload_name(name, payload[:name])
      sql  = color(sql, sql_color(sql), bold: true) if colorize_logging

      debug "  #{name}  #{sql}#{binds}"
    end
    event_log_level :sql, :debug

    def self.default_logger
      ActiveRecord::Base.logger
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
          color(name, MAGENTA, bold: true)
        else
          color(name, CYAN, bold: true)
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

      def debug(progname = nil, &block)
        return unless super

        if ActiveRecord.verbose_query_logs
          log_query_source
        end
      end

      def log_query_source
        source = query_source_location

        if source
          logger.debug("  ↳ #{source}")
        end
      end

      def query_source_location
        backtrace_cleaner.first_clean_frame
      end

      def filter(name, value)
        ActiveRecord::Base.inspection_filter.filter_param(name, value)
      end
  end
end

ActiveSupport.event_reporter.subscribe(
  ActiveRecord::LogSubscriber.new, &ActiveRecord::LogSubscriber.subscription_filter
)
