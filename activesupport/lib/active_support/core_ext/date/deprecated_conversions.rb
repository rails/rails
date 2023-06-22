# frozen_string_literal: true

require "date"

class Date
  NOT_SET = Object.new # :nodoc:
  def to_s(format = NOT_SET) # :nodoc:
    if formatter = DATE_FORMATS[format]
      ActiveSupport::Deprecation.warn(
        "Date#to_s(#{format.inspect}) is deprecated. Please use Date#to_fs(#{format.inspect}) instead."
      )
      if formatter.respond_to?(:call)
        formatter.call(self).to_s
      else
        strftime(formatter)
      end
    elsif format == NOT_SET
      if formatter = DATE_FORMATS[:default]
        ActiveSupport::Deprecation.warn(
          "Using a :default format for Date#to_s is deprecated. Please use Date#to_fs instead."
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
        "Date#to_s(#{format.inspect}) is deprecated. Please use Date#to_fs(#{format.inspect}) instead."
      )
      to_default_s
    end
  end
end
