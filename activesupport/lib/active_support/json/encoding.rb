require 'active_support/json/variable'
require 'active_support/json/encoders/object' # Require explicitly for rdoc.
Dir["#{File.dirname(__FILE__)}/encoders/**/*.rb"].each do |file|
  basename = File.basename(file, '.rb')
  unless basename == 'object'
    require "active_support/json/encoders/#{basename}"
  end
end

module ActiveSupport
  module JSON
    class CircularReferenceError < StandardError
    end

    # Converts a Ruby object into a JSON string.
    def self.encode(value, options = {})
      seen = (options[:seen] ||= [])
      raise CircularReferenceError, 'object references itself' if seen.include?(value)
      seen << value
      value.send(:to_json, options)
    ensure
      seen.pop
    end
  end
end
