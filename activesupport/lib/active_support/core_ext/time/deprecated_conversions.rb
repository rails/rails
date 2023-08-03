# frozen_string_literal: true

require "time"

class Time
  NOT_SET = Object.new # :nodoc:
  def to_s(format = NOT_SET) # :nodoc:
    if formatter = DATE_FORMATS[format]
      ActiveSupport::Deprecation.warn(
        "Time#to_s(#{format.inspect}) is deprecated. Please use Time#to_fs(#{format.inspect}) instead."
      )
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    elsif format == NOT_SET
      if formatter = ::Time::DATE_FORMATS[:default]
        ActiveSupport::Deprecation.warn(
          "Using a :default format for Time#to_s is deprecated. Please use Time#to_fs instead."
        )
        if formatter.respond_to?(:call)
          formatter.call(self).to_s
        else
          strftime(formatter)
        end
      else
        to_default_s
      end
    else
      ActiveSupport::Deprecation.warn(
        "Time#to_s(#{format.inspect}) is deprecated. Please use Time#to_fs(#{format.inspect}) instead."
      )
      to_default_s
    end
  end
end
