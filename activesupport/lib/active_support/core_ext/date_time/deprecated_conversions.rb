# frozen_string_literal: true

require "date"

class DateTime
  NOT_SET = Object.new # :nodoc:
  def to_s(format = NOT_SET) # :nodoc:
    if formatter = ::Time::DATE_FORMATS[format]
      ActiveSupport::Deprecation.warn(
        "DateTime#to_s(#{format.inspect}) is deprecated. Please use DateTime#to_fs(#{format.inspect}) instead."
      )
      formatter.respond_to?(:call) ? formatter.call(self).to_s : strftime(formatter)
    elsif format == NOT_SET
      to_default_s
    else
      ActiveSupport::Deprecation.warn(
        "DateTime#to_s(#{format.inspect}) is deprecated. Please use DateTime#to_fs(#{format.inspect}) instead."
      )
      to_default_s
    end
  end
end
