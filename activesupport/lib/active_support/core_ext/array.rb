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
  
  # Divide the array into one or more subarrays based on a delimiting +value+
  # or the result of an optional block.
  #
  # ex.
  #
  #   [1, 2, 3, 4, 5].split(3)                # => [[1, 2], [4, 5]]
  #   (1..10).to_a.split { |i| i % 3 == 0 }   # => [[1, 2], [4, 5], [7, 8], [10]]
  def split(value = nil, &block)
    block ||= Proc.new { |e| e == value }
    inject([[]]) do |results, element|
      if block.call(element)
        results << []
      else
        results.last << element
      end
      results
    end
  end
end
