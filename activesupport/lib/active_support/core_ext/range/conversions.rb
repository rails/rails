# frozen_string_literal: true

module ActiveSupport
  # = \Range With Format
  module RangeWithFormat
    RANGE_FORMATS = {
      db: -> (start, stop) do
        if start && stop
          case start
          when String then "BETWEEN '#{start}' AND '#{stop}'"
          else
            "BETWEEN '#{start.to_fs(:db)}' AND '#{stop.to_fs(:db)}'"
          end
        elsif start
          case start
          when String then ">= '#{start}'"
          else
            ">= '#{start.to_fs(:db)}'"
          end
        elsif stop
          case stop
          when String then "<= '#{stop}'"
          else
            "<= '#{stop.to_fs(:db)}'"
          end
        end
      end
    }

    # Convert range to a formatted string. See RANGE_FORMATS for predefined formats.
    #
    # This method is aliased to <tt>to_formatted_s</tt>.
    #
    #   range = (1..100)           # => 1..100
    #
    #   range.to_s                 # => "1..100"
    #   range.to_fs(:db)           # => "BETWEEN '1' AND '100'"
    #
    #   range = (1..)              # => 1..
    #   range.to_fs(:db)           # => ">= '1'"
    #
    #   range = (..100)            # => ..100
    #   range.to_fs(:db)           # => "<= '100'"
    #
    # == Adding your own range formats to to_fs
    # You can add your own formats to the Range::RANGE_FORMATS hash.
    # Use the format name as the hash key and a Proc instance.
    #
    #   # config/initializers/range_formats.rb
    #   Range::RANGE_FORMATS[:short] = ->(start, stop) { "Between #{start.to_fs(:db)} and #{stop.to_fs(:db)}" }
    def to_fs(format = :default)
      if formatter = RANGE_FORMATS[format]
        formatter.call(self.begin, self.end)
      else
        to_s
      end
    end
    alias_method :to_formatted_s, :to_fs
  end
end

Range.prepend(ActiveSupport::RangeWithFormat)
