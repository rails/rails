# frozen_string_literal: true

require "active_support/notifications"
require "active_support/core_ext/array/conversions"

module ActiveRecord::Associations::Deprecation # :nodoc:
  EVENT = "deprecated_association.active_record"
  private_constant :EVENT

  MODES = [:warn, :raise, :notify].freeze
  private_constant :MODES

  class << self
    attr_reader :mode, :backtrace

    def mode=(value) # private setter
      unless MODES.include?(value)
        raise ArgumentError, "invalid deprecated associations mode #{value.inspect} (valid modes are #{MODES.map(&:inspect).to_sentence})"
      end

      @mode = value
    end

    def backtrace=(value)
      @backtrace = !!value
    end

    def guard(reflection)
      report(reflection, context: yield) if reflection.deprecated?

      if reflection.through_reflection?
        reflection.deprecated_nested_reflections.each do |deprecated_nested_reflection|
          context = "referenced as nested association of the through #{reflection.active_record}##{reflection.name}"
          report(deprecated_nested_reflection, context: context)
        end
      end
    end

    def report(reflection, context:)
      reflection = user_facing_reflection(reflection)

      message = +"The association #{reflection.active_record}##{reflection.name} is deprecated, #{context}"
      message << " (#{backtrace_cleaner.first_clean_frame})"

      case @mode
      when :warn
        message = [message, *clean_frames].join("\n\t") if @backtrace
        ActiveRecord::Base.logger&.warn(message)
      when :raise
        error = ActiveRecord::DeprecatedAssociationError.new(message)
        if set_backtrace_supports_array_of_locations?
          error.set_backtrace(clean_locations)
        else
          error.set_backtrace(clean_frames)
        end
        raise error
      else
        payload = { reflection: reflection, message: message, location: backtrace_cleaner.first_clean_location }
        payload[:backtrace] = clean_locations if @backtrace
        ActiveSupport::Notifications.instrument(EVENT, payload)
      end
    end

    private
      def backtrace_cleaner
        ActiveRecord::LogSubscriber.backtrace_cleaner
      end

      def clean_frames
        backtrace_cleaner.clean(caller)
      end

      def clean_locations
        backtrace_cleaner.clean_locations(caller_locations)
      end

      def set_backtrace_supports_array_of_locations?
        @backtrace_supports_array_of_locations ||= Gem::Version.new(RUBY_VERSION) >= Gem::Version.new("3.4.0")
      end

      def user_facing_reflection(reflection)
        reflection.active_record.reflect_on_association(reflection.name)
      end
  end

  self.mode = :warn
  self.backtrace = false
end
