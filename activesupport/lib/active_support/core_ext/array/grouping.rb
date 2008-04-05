require 'enumerator'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Grouping
        # Iterates over the array in groups of size +number+, padding any remaining 
        # slots with +fill_with+ unless it is +false+.
        # 
        #   %w(1 2 3 4 5 6 7).in_groups_of(3) {|g| p g}
        #   ["1", "2", "3"]
        #   ["4", "5", "6"]
        #   ["7", nil, nil]
        #
        #   %w(1 2 3).in_groups_of(2, '&nbsp;') {|g| p g}
        #   ["1", "2"]
        #   ["3", "&nbsp;"]
        #
        #   %w(1 2 3).in_groups_of(2, false) {|g| p g}
        #   ["1", "2"]
        #   ["3"]
        def in_groups_of(number, fill_with = nil, &block)
          if fill_with == false
            collection = self
          else
            # size % number gives how many extra we have;
            # subtracting from number gives how many to add;
            # modulo number ensures we don't add group of just fill.
            padding = (number - size % number) % number
            collection = dup.concat([fill_with] * padding)
          end

          if block_given?
            collection.each_slice(number, &block)
          else
            returning [] do |groups|
              collection.each_slice(number) { |group| groups << group }
            end
          end
        end

        # Divides the array into one or more subarrays based on a delimiting +value+
        # or the result of an optional block.
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
    end
  end
end
