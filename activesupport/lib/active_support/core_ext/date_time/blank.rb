require "date"

class DateTime #:nodoc:
  # No DateTime is ever blank:
  #
  #   DateTime.now.empty? # => false
  #   DateTime.now.blank? # => false
  #
  # @return [false]
  def empty?
    false
  end
end
