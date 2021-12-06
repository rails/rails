# frozen_string_literal: true

require "time"

class Time
  NOT_SET = Object.new # :nodoc:
  def to_s(format = NOT_SET) # :nodoc:
    if formatter = DATE_FORMATS[format]
      ActiveSupport::Deprecation.warn(
        "Time#to_s(#{format.inspect}) is deprecated. Please use Time#to_formatted_s(#{format.inspect}) instead."
      )
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    elsif format == NOT_SET
      to_default_s
    else
      ActiveSupport::Deprecation.warn(
        "Time#to_s(#{format.inspect}) is deprecated. Please use Time#to_formatted_s(#{format.inspect}) instead."
      )
      to_default_s
    end
  end
end
