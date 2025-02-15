# frozen_string_literal: true

module ActiveSupport
  module Testing
    module ErrorReporterAssertions
      module ErrorCollector # :nodoc:
        @subscribed = false
        @mutex = Mutex.new

        Report = Struct.new(:error, :handled, :severity, :context, :source, keyword_init: true)
        class Report
          alias_method :handled?, :handled
        end

        class << self
          def record
            subscribe
            recorders = ActiveSupport::IsolatedExecutionState[:active_support_error_reporter_assertions] ||= []
            reports = []
            recorders << reports
            begin
              yield
              reports
            ensure
              recorders.delete_if { |r| reports.equal?(r) }
            end
          end

          def report(error, **kwargs)
            report = Report.new(error: error, **kwargs)
            ActiveSupport::IsolatedExecutionState[:active_support_error_reporter_assertions]&.each do |reports|
              reports << report
            end
            true
          end

          private
            def subscribe
              return if @subscribed
              @mutex.synchronize do
                return if @subscribed

                if ActiveSupport.error_reporter
                  ActiveSupport.error_reporter.subscribe(self)
                  @subscribed = true
                else
                  flunk("No error reporter is configured")
                end
              end
            end
        end
      end

      # Assertion that the block should not cause an exception to be reported
      # to +Rails.error+.
      #
      # Passes if evaluated code in the yielded block reports no exception.
      #
      #   assert_no_error_reported do
      #     perform_service(param: 'no_exception')
      #   end
      def assert_no_error_reported(&block)
        reports = ErrorCollector.record do
          _assert_nothing_raised_or_warn("assert_no_error_reported", &block)
        end
        assert_predicate(reports, :empty?)
      end

      # Assertion that the block should cause at least one exception to be reported
      # to +Rails.error+.
      #
      # Passes if the evaluated code in the yielded block reports a matching exception.
      #
      #   assert_error_reported(IOError) do
      #     Rails.error.report(IOError.new("Oops"))
      #   end
      #
      # To test further details about the reported exception, you can use the return
      # value.
      #
      #   report = assert_error_reported(IOError) do
      #     # ...
      #   end
      #   assert_equal "Oops", report.error.message
      #   assert_equal "admin", report.context[:section]
      #   assert_equal :warning, report.severity
      #   assert_predicate report, :handled?
      def assert_error_reported(error_class = StandardError, &block)
        reports = ErrorCollector.record do
          _assert_nothing_raised_or_warn("assert_error_reported", &block)
        end

        if reports.empty?
          assert(false, "Expected a #{error_class.name} to be reported, but there were no errors reported.")
        elsif (report = reports.find { |r| error_class === r.error })
          self.assertions += 1
          report
        else
          message = "Expected a #{error_class.name} to be reported, but none of the " \
            "#{reports.size} reported errors matched:  \n" \
            "#{reports.map { |r| r.error.class.name }.join("\n  ")}"
          assert(false, message)
        end
      end
    end
  end
end
