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
        # matches YAML-formatted dates
        DATE_REGEX = /^(?:\d{4}-\d{2}-\d{2}|\d{4}-\d{1,2}-\d{1,2}[ \t]+\d{1,2}:\d{2}:\d{2}(\.[0-9]*)?(([ \t]*)Z|[-+]\d{2}?(:\d{2})?)?)$/

        # Ensure that ":" and "," are always followed by a space
        def convert_json_to_yaml(json) #:nodoc:
          scanner, quoting, marks, pos, times = StringScanner.new(json), false, [], nil, []
          while scanner.scan_until(/(\\['"]|['":,\\]|\\.)/)
            case char = scanner[1]
            when '"', "'"
              if !quoting
                quoting = char
                pos = scanner.pos
              elsif quoting == char
                if json[pos..scanner.pos-2] =~ DATE_REGEX
                  # found a date, track the exact positions of the quotes so we can remove them later.
                  # oh, and increment them for each current mark, each one is an extra padded space that bumps
                  # the position in the final YAML output
                  total_marks = marks.size
                  times << pos+total_marks << scanner.pos+total_marks
                end
                quoting = false
              end
            when ":",","
              marks << scanner.pos - 1 unless quoting
            end
          end

          if marks.empty?
            json.gsub(/\\([\\\/]|u[[:xdigit:]]{4})/) do
              ustr = $1
              if ustr.starts_with?('u')
                [ustr[1..-1].to_i(16)].pack("U")
              elsif ustr == '\\'
                '\\\\'
              else
                ustr
              end
            end
          else
            left_pos  = [-1].push(*marks)
            right_pos = marks << scanner.pos + scanner.rest_size
            output    = []
            left_pos.each_with_index do |left, i|
              scanner.pos = left.succ
              output << scanner.peek(right_pos[i] - scanner.pos + 1).gsub(/\\([\\\/]|u[[:xdigit:]]{4})/) do
                ustr = $1
                if ustr.starts_with?('u')
                  [ustr[1..-1].to_i(16)].pack("U")
                elsif ustr == '\\'
                '\\\\'
                else
                  ustr
                end
              end
            end
            output = output * " "
            
            times.each { |i| output[i-1] = ' ' }
            output.gsub!(/\\\//, '/')
            output
          end
        end
    end
  end
end
