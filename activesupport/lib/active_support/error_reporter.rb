# frozen_string_literal: true

module ActiveSupport
  # = Active Support \Error Reporter
  #
  # +ActiveSupport::ErrorReporter+ is a common interface for error reporting services.
  #
  # To rescue and report any unhandled error, you can use the #handle method:
  #
  #   Rails.error.handle do
  #     do_something!
  #   end
  #
  # If an error is raised, it will be reported and swallowed.
  #
  # Alternatively, if you want to report the error but not swallow it, you can use #record:
  #
  #   Rails.error.record do
  #     do_something!
  #   end
  #
  # Both methods can be restricted to handle only a specific error class:
  #
  #   maybe_tags = Rails.error.handle(Redis::BaseError) { redis.get("tags") }
  #
  class ErrorReporter
    SEVERITIES = %i(error warning info)
    DEFAULT_SOURCE = "application"

    attr_accessor :logger

    def initialize(*subscribers, logger: nil)
      @subscribers = subscribers.flatten
      @logger = logger
    end

    # Evaluates the given block, reporting and swallowing any unhandled error.
    # If no error is raised, returns the return value of the block. Otherwise,
    # returns the result of +fallback.call+, or +nil+ if +fallback+ is not
    # specified.
    #
    #   # Will report a TypeError to all subscribers and return nil.
    #   Rails.error.handle do
    #     1 + '1'
    #   end
    #
    # Can be restricted to handle only specific error classes:
    #
    #   maybe_tags = Rails.error.handle(Redis::BaseError) { redis.get("tags") }
    #
    # ==== Options
    #
    # * +:severity+ - This value is passed along to subscribers to indicate how
    #   important the error report is. Can be +:error+, +:warning+, or +:info+.
    #   Defaults to +:warning+.
    #
    # * +:context+ - Extra information that is passed along to subscribers. For
    #   example:
    #
    #     Rails.error.handle(context: { section: "admin" }) do
    #       # ...
    #     end
    #
    # * +:fallback+ - A callable that provides +handle+'s return value when an
    #   unhandled error is raised. For example:
    #
    #     user = Rails.error.handle(fallback: -> { User.anonymous }) do
    #       User.find_by(params)
    #     end
    #
    # * +:source+ - This value is passed along to subscribers to indicate the
    #   source of the error. Subscribers can use this value to ignore certain
    #   errors. Defaults to <tt>"application"</tt>.
    def handle(*error_classes, severity: :warning, context: {}, fallback: nil, source: DEFAULT_SOURCE)
      error_classes = [StandardError] if error_classes.blank?
      yield
    rescue *error_classes => error
      report(error, handled: true, severity: severity, context: context, source: source)
      fallback.call if fallback
    end

    # Evaluates the given block, reporting and re-raising any unhandled error.
    # If no error is raised, returns the return value of the block.
    #
    #   # Will report a TypeError to all subscribers and re-raise it.
    #   Rails.error.record do
    #     1 + '1'
    #   end
    #
    # Can be restricted to handle only specific error classes:
    #
    #   tags = Rails.error.record(Redis::BaseError) { redis.get("tags") }
    #
    # ==== Options
    #
    # * +:severity+ - This value is passed along to subscribers to indicate how
    #   important the error report is. Can be +:error+, +:warning+, or +:info+.
    #   Defaults to +:error+.
    #
    # * +:context+ - Extra information that is passed along to subscribers. For
    #   example:
    #
    #     Rails.error.record(context: { section: "admin" }) do
    #       # ...
    #     end
    #
    # * +:source+ - This value is passed along to subscribers to indicate the
    #   source of the error. Subscribers can use this value to ignore certain
    #   errors. Defaults to <tt>"application"</tt>.
    def record(*error_classes, severity: :error, context: {}, source: DEFAULT_SOURCE)
      error_classes = [StandardError] if error_classes.blank?
      yield
    rescue *error_classes => error
      report(error, handled: false, severity: severity, context: context, source: source)
      raise
    end

    # Register a new error subscriber. The subscriber must respond to
    #
    #   report(Exception, handled: Boolean, severity: (:error OR :warning OR :info), context: Hash, source: String)
    #
    # The +report+ method <b>should never</b> raise an error.
    def subscribe(subscriber)
      unless subscriber.respond_to?(:report)
        raise ArgumentError, "Error subscribers must respond to #report"
      end
      @subscribers << subscriber
    end

    # Unregister an error subscriber. Accepts either a subscriber or a class.
    #
    #   subscriber = MyErrorSubscriber.new
    #   Rails.error.subscribe(subscriber)
    #
    #   Rails.error.unsubscribe(subscriber)
    #   # or
    #   Rails.error.unsubscribe(MyErrorSubscriber)
    def unsubscribe(subscriber)
      @subscribers.delete_if { |s| subscriber === s }
    end

    # Prevent a subscriber from being notified of errors for the
    # duration of the block. You may pass in the subscriber itself, or its class.
    #
    # This can be helpful for error reporting service integrations, when they wish
    # to handle any errors higher in the stack.
    def disable(subscriber)
      disabled_subscribers = (ActiveSupport::IsolatedExecutionState[self] ||= [])
      disabled_subscribers << subscriber
      begin
        yield
      ensure
        disabled_subscribers.delete(subscriber)
      end
    end

    # Update the execution context that is accessible to error subscribers. Any
    # context passed to #handle, #record, or #report will be merged with the
    # context set here.
    #
    #   Rails.error.set_context(section: "checkout", user_id: @user.id)
    #
    def set_context(...)
      ActiveSupport::ExecutionContext.set(...)
    end

    # Report an error directly to subscribers. You can use this method when the
    # block-based #handle and #record methods are not suitable.
    #
    #   Rails.error.report(error)
    #
    def report(error, handled: true, severity: handled ? :warning : :error, context: {}, source: DEFAULT_SOURCE)
      return if error.instance_variable_defined?(:@__rails_error_reported)

      unless SEVERITIES.include?(severity)
        raise ArgumentError, "severity must be one of #{SEVERITIES.map(&:inspect).join(", ")}, got: #{severity.inspect}"
      end

      full_context = ActiveSupport::ExecutionContext.to_h.merge(context)
      disabled_subscribers = ActiveSupport::IsolatedExecutionState[self]
      @subscribers.each do |subscriber|
        unless disabled_subscribers&.any? { |s| s === subscriber }
          subscriber.report(error, handled: handled, severity: severity, context: full_context, source: source)
        end
      rescue => subscriber_error
        if logger
          logger.fatal(
            "Error subscriber raised an error: #{subscriber_error.message} (#{subscriber_error.class})\n" +
            subscriber_error.backtrace.join("\n")
          )
        else
          raise
        end
      end

      unless error.frozen?
        error.instance_variable_set(:@__rails_error_reported, true)
      end

      nil
    end
  end
end
