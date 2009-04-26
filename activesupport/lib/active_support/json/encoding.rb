module ActiveSupport
  module JSON
    class CircularReferenceError < StandardError
    end

    # Converts a Ruby object into a JSON string.
    def self.encode(value, options = nil)
      options ||= {}
      seen = (options[:seen] ||= [])
      raise CircularReferenceError, 'object references itself' if seen.include?(value)
      seen << value
      value.rails_to_json(options)
    ensure
      seen.pop
    end
  end
end

require 'active_support/json/variable'
require 'active_support/json/encoders/date'
require 'active_support/json/encoders/date_time'
require 'active_support/json/encoders/enumerable'
require 'active_support/json/encoders/false_class'
require 'active_support/json/encoders/hash'
require 'active_support/json/encoders/nil_class'
require 'active_support/json/encoders/numeric'
require 'active_support/json/encoders/object'
require 'active_support/json/encoders/regexp'
require 'active_support/json/encoders/string'
require 'active_support/json/encoders/symbol'
require 'active_support/json/encoders/time'
require 'active_support/json/encoders/true_class'
