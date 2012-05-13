class Range
  RANGE_FORMATS = {
    :db => Proc.new do |start, stop|
      formatted_start = start.to_formatted_s(:db)
      formatted_stop  = stop.to_formatted_s(:db)

      if formatted_start.is_a?(String)
        "BETWEEN '#{formatted_start}' AND '#{formatted_stop}'"
      else
        "BETWEEN #{formatted_start} AND #{formatted_stop}"
      end
    end
  }

  # Gives a human readable format of the range.
  #
  # ==== Example
  #
  #   (1..100).to_formatted_s # => "1..100"
  def to_formatted_s(format = :default)
    if formatter = RANGE_FORMATS[format]
      formatter.call(first, last)
    else
      to_default_s
    end
  end

  alias_method :to_default_s, :to_s
  alias_method :to_s, :to_formatted_s
end
