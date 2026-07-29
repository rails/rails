# frozen_string_literal: true

module ActiveSupport
  # = \Range With Format
  module RangeWithFormat
    RANGE_FORMATS = {
      db: -> (range) do
        start, stop = range.begin, range.end
        exclusive = range.exclude_end?

        format_bound = ->(value) do
          case value
          when String then value
          else value.to_fs(:db)
          end
        end

        if start && stop
          if exclusive
            ">= '#{format_bound[start]}' AND < '#{format_bound[stop]}'"
          else
            "BETWEEN '#{format_bound[start]}' AND '#{format_bound[stop]}'"
          end
        elsif start
          ">= '#{format_bound[start]}'"
        elsif stop
          if exclusive
            "< '#{format_bound[stop]}'"
          else
            "<= '#{format_bound[stop]}'"
          end
        end
      end
    }.freeze

    # Convert range to a formatted string. See RANGE_FORMATS for predefined formats.
    #
    # This method is aliased to <tt>to_formatted_s</tt>.
    #
    #   range = (1..100)           # => 1..100
    #
    #   range.to_s                 # => "1..100"
    #   range.to_fs(:db)           # => "BETWEEN '1' AND '100'"
    #
    #   range = (1...100)          # => 1...100
    #   range.to_fs(:db)           # => ">= '1' AND < '100'"
    #
    #   range = (1..)              # => 1..
    #   range.to_fs(:db)           # => ">= '1'"
    #
    #   range = (..100)            # => ..100
    #   range.to_fs(:db)           # => "<= '100'"
    #
    #   range = (...100)           # => ...100
    #   range.to_fs(:db)           # => "< '100'"
    def to_fs(format = :default)
      if formatter = RANGE_FORMATS[format]
        formatter.call(self)
      else
        to_s
      end
    end
    alias_method :to_formatted_s, :to_fs
  end
end

Range.prepend(ActiveSupport::RangeWithFormat)
