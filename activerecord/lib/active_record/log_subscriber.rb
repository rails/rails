# frozen_string_literal: true

module ActiveRecord
  class LogSubscriber < ActiveSupport::LogSubscriber
    IGNORE_PAYLOAD_NAMES = ["SCHEMA", "EXPLAIN"]

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

    def sql(event)
      self.class.runtime += event.duration
      return unless logger.debug?

      payload = event.payload

      return if IGNORE_PAYLOAD_NAMES.include?(payload[:name])

      name  = "#{payload[:name]} (#{event.duration.round(1)}ms)"
      name  = "CACHE #{name}" if payload[:cached]
      sql   = payload[:sql]
      binds = nil

      unless (payload[:binds] || []).empty?
        casted_params = type_casted_binds(payload[:type_casted_binds])
        binds = "  " + payload[:binds].zip(casted_params).map { |attr, value|
          render_bind(attr, value)
        }.inspect
      end

      name = colorize_payload_name(name, payload[:name])
      sql  = color(sql, sql_color(sql), true)

      debug "  #{name}  #{sql}#{binds}"
    end

    private
      def type_casted_binds(casted_binds)
        casted_binds.respond_to?(:call) ? casted_binds.call : casted_binds
      end

      def render_bind(attr, value)
        if attr.is_a?(Array)
          attr = attr.first
        elsif attr.type.binary? && attr.value
          value = "<#{attr.value_for_database.to_s.bytesize} bytes of binary data>"
        end

        [attr && attr.name, value]
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
        source_line, line_number = extract_callstack(caller_locations)

        if source_line
          if defined?(::Rails.root)
            app_root = "#{::Rails.root.to_s}/"
            source_line = source_line.sub(app_root, "")
          end

          logger.debug("  ↳ #{ source_line }:#{ line_number }")
        end
      end

      def extract_callstack(callstack)
        line = callstack.find do |frame|
          frame.absolute_path && !ignored_callstack(frame.absolute_path)
        end

        offending_line = line || callstack.first

        [
          offending_line.path,
          offending_line.lineno
        ]
      end

      RAILS_GEM_ROOT = File.expand_path("../../../..", __FILE__) + "/"

      def ignored_callstack(path)
        path.start_with?(RAILS_GEM_ROOT) ||
        path.start_with?(RbConfig::CONFIG["rubylibdir"])
      end
  end
end

ActiveRecord::LogSubscriber.attach_to :active_record
