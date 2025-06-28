# frozen_string_literal: true

require "active_support/notifications"
require "active_support/core_ext/array/conversions"

module ActiveRecord::Associations::Deprecation # :nodoc:
  EVENT = "deprecated_association.active_record"
  private_constant :EVENT

  MODES = [:warn, :raise, :notify].freeze
  private_constant :MODES

  DEFAULT_MODE = :warn
  private_constant :DEFAULT_MODE

  DEFAULT_BACKTRACE = false
  private_constant :DEFAULT_BACKTRACE

  class << self
    attr_reader :options

    def options=(options)
      raise ArgumentError, "deprecated associations options must be a hash" unless options.is_a?(Hash)

      options.each_key do |key|
        unless [:mode, :backtrace].include?(key)
          raise ArgumentError, "Invalid deprecated associations option #{key.inspect}. Valid options are :mode and :backtrace."
        end
      end

      mode = options.fetch(:mode, DEFAULT_MODE)
      unless MODES.include?(mode)
        raise ArgumentError, "Invalid deprecated associations mode #{mode.inspect}. Valid modes are #{MODES.map(&:inspect).to_sentence}."
      end

      backtrace = options.fetch(:backtrace, DEFAULT_BACKTRACE)

      @mode = mode
      @backtrace = backtrace
    end

    def guard(reflection)
      report(reflection, context: yield) if reflection.deprecated?

      if reflection.through_reflection?
        reflection.deprecated_nested_reflections.each do |deprecated_nested_reflection|
          report(
            deprecated_nested_reflection,
            context: "referenced as nested association of the through #{reflection.active_record}##{reflection.name}"
          )
        end
      end
    end

    def report(reflection, context:)
      message = "The association #{reflection.active_record}##{reflection.name} is deprecated, #{context}"

      backtrace_cleaner = ActiveRecord::LogSubscriber.backtrace_cleaner
      backtrace = backtrace_cleaner.clean(caller).join("\n") if @backtrace

      case @mode
      when :warn
        if @backtrace
          ActiveRecord::Base.logger&.warn("#{message}\n#{backtrace}")
        else
          ActiveRecord::Base.logger&.warn("#{message} (#{backtrace_cleaner.first_clean_frame})")
        end
      when :raise
        first_clean_frame = ActiveRecord::LogSubscriber.backtrace_cleaner.first_clean_frame
        raise ActiveRecord::DeprecatedAssociationError.new("#{message} (#{first_clean_frame})")
      else
        payload = { reflection: reflection, message: message, location: backtrace_cleaner.first_clean_location }
        payload[:backtrace] = backtrace if @backtrace
        ActiveSupport::Notifications.instrument(EVENT, payload)
      end
    end
  end

  self.options = { mode: DEFAULT_MODE, backtrace: DEFAULT_BACKTRACE }.freeze
end
