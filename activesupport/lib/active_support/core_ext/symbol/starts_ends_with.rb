# frozen_string_literal: true

class Symbol
  def start_with?(*prefixes)
    to_s.start_with?(*prefixes)
  end unless :a.respond_to?(:start_with?)

  def end_with?(*suffixes)
    to_s.end_with?(*suffixes)
  end unless :a.respond_to?(:end_with?)

  alias :starts_with? :start_with?
  alias :ends_with? :end_with?
end
