# frozen_string_literal: true

class Symbol
  def start_with?(prefix)
    to_s.start_with?(prefix)
  end unless :a.respond_to?(:start_with?)

  def end_with?(suffix)
    to_s.end_with?(suffix)
  end unless :a.respond_to?(:end_with?)

  alias :starts_with? :start_with?
  alias :ends_with? :end_with?
end
