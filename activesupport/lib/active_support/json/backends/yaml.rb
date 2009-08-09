require 'active_support/core_ext/string/starts_ends_with'

module ActiveSupport
  module JSON
    unless const_defined?(:ParseError)
      class ParseError < StandardError
      end
    end

    module Backends
      module Yaml
        extend self

        # Parses a JSON string or IO and converts it into an object
        def decode(json)
          if json.respond_to?(:read)
            json = json.read
          end
          YAML.load(convert_json_to_yaml(json))
        rescue ArgumentError => e
          raise ParseError, "Invalid JSON string"
        end

        protected
          # Ensure that ":" and "," are always followed by a space
          def convert_json_to_yaml(json) #:nodoc:
            require 'strscan' unless defined? ::StringScanner
            scanner, quoting, marks, pos, times = ::StringScanner.new(json), false, [], nil, []
            while scanner.scan_until(/(\\['"]|['":,\\]|\\.)/)
              case char = scanner[1]
              when '"', "'"
                if !quoting
                  quoting = char
                  pos = scanner.pos
                elsif quoting == char
                  if json[pos..scanner.pos-2] =~ DATE_REGEX
                    # found a date, track the exact positions of the quotes so we can
                    # overwrite them with spaces later.
                    times << pos << scanner.pos
                  end
                  quoting = false
                end
              when ":",","
                marks << scanner.pos - 1 unless quoting
              when "\\"
                scanner.skip(/\\/)
              end
            end

            if marks.empty?
              json.gsub(/\\([\\\/]|u[[:xdigit:]]{4})/) do
                ustr = $1
                if ustr.start_with?('u')
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
                chunk = scanner.peek(right_pos[i] - scanner.pos + 1)
                # overwrite the quotes found around the dates with spaces
                while times.size > 0 && times[0] <= right_pos[i]
                  chunk[times.shift - scanner.pos - 1] = ' '
                end
                chunk.gsub!(/\\([\\\/]|u[[:xdigit:]]{4})/) do
                  ustr = $1
                  if ustr.start_with?('u')
                    [ustr[1..-1].to_i(16)].pack("U")
                  elsif ustr == '\\'
                    '\\\\'
                  else
                    ustr
                  end
                end
                output << chunk
              end
              output = output * " "

              output.gsub!(/\\\//, '/')
              output
            end
          end
      end
    end
  end
end

