require 'yaml'
require 'strscan'

module ActiveSupport
  module JSON
    class ParseError < StandardError
    end
    
    class << self
      # Converts a JSON string into a Ruby object.
      def decode(json)
        YAML.load(convert_json_to_yaml(json))
      rescue ArgumentError => e
        raise ParseError, "Invalid JSON string"
      end
      
      protected
        # Ensure that ":" and "," are always followed by a space
        def convert_json_to_yaml(json) #:nodoc:
          scanner, quoting, marks = StringScanner.new(json), false, []

          while scanner.scan_until(/(['":,]|\\.)/)
            case char = scanner[1]
            when '"', "'"
              quoting = quoting == char ? false : char
            when ":", ","
              marks << scanner.pos - 1 unless quoting
            end
          end
          
          if marks.empty?
            json
          else
            ranges = ([0] + marks.map(&:succ)).zip(marks + [json.length])
            ranges.map { |(left, right)| json[left..right] }.join(" ")
          end
        end  
    end
  end
end
