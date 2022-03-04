# frozen_string_literal: true

require "pathname"

class Pathname
  # An Pathname is blank if it's empty:
  #
  #   Pathname.new("").blank?      # => true
  #   Pathname.new(" ").blank?     # => false
  #   Pathname.new("test").blank?  # => false
  #
  # @return [true, false]
  def blank?
    to_s.empty?
  end
end
