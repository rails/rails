require File.dirname(__FILE__) + '/array/conversions'

class Array #:nodoc:
  include ActiveSupport::CoreExtensions::Array::Conversions

  # Iterate over an array in groups of a certain size, padding any remaining 
  # slots with specified value (<tt>nil</tt> by default).
  # 
  # E.g.
  # 
  #   %w(1 2 3 4 5 6 7).in_groups_of(3) {|g| p g}
  #   ["1", "2", "3"]
  #   ["4", "5", "6"]
  #   ["7", nil, nil]
  def in_groups_of(number, fill_with = nil, &block)
    require 'enumerator'
    collection = dup
    collection << fill_with until collection.size.modulo(number).zero?
    collection.each_slice(number, &block)
  end
end
