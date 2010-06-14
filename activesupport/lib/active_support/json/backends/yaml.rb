require 'active_support/core_ext/string/starts_ends_with'

module ActiveSupport
  module JSON
    module Backends
      module Yaml
        ParseError = ::StandardError
        extend self

        EXCEPTIONS = [::ArgumentError] # :nodoc:
        begin
          require 'psych'
          EXCEPTIONS << Psych::SyntaxError
        rescue LoadError
        end

        # Parses a JSON string or IO and converts it into an object
        def decode(json)
          if json.respond_to?(:read)
            json = json.read
          end
          YAML.load(convert_json_to_yaml(json))
        rescue *EXCEPTIONS => e
          raise ParseError, "Invalid JSON string: '%s'" % json
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
                  if valid_date?(json[pos..scanner.pos-2])
                    # found a date, track the exact positions of the quotes so we can
                    # overwrite them with spaces later.
                    times << pos
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
                  char = [ustr[1..-1].to_i(16)].pack("U")
                  # "\n" needs extra escaping due to yaml formatting
                  char == "\n" ? "\\n" : char
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
                  chunk.insert(times.shift - scanner.pos - 1, '! ')
                end
                chunk.gsub!(/\\([\\\/]|u[[:xdigit:]]{4})/) do
                  ustr = $1
                  if ustr.start_with?('u')
                    char = [ustr[1..-1].to_i(16)].pack("U")
                    # "\n" needs extra escaping due to yaml formatting
                    char == "\n" ? "\\n" : char
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

        private
          def valid_date?(date_string)
            begin
              date_string =~ DATE_REGEX && DateTime.parse(date_string)
            rescue ArgumentError
              false
            end
          end

      end
    end
  end
end

