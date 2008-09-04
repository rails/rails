require 'enumerator'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Array #:nodoc:
      module Grouping
        # Splits or iterates over the array in groups of size +number+,
        # padding any remaining slots with +fill_with+ unless it is +false+.
        # 
        #   %w(1 2 3 4 5 6 7).in_groups_of(3) {|group| p group}
        #   ["1", "2", "3"]
        #   ["4", "5", "6"]
        #   ["7", nil, nil]
        #
        #   %w(1 2 3).in_groups_of(2, '&nbsp;') {|group| p group}
        #   ["1", "2"]
        #   ["3", "&nbsp;"]
        #
        #   %w(1 2 3).in_groups_of(2, false) {|group| p group}
        #   ["1", "2"]
        #   ["3"]
        def in_groups_of(number, fill_with = nil)
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
            collection.each_slice(number) { |slice| yield(slice) }
          else
            returning [] do |groups|
              collection.each_slice(number) { |group| groups << group }
            end
          end
        end

        # Splits or iterates over the array in +number+ of groups, padding any
        # remaining slots with +fill_with+ unless it is +false+.
        #
        #   %w(1 2 3 4 5 6 7 8 9 10).in_groups(3) {|group| p group}
        #   ["1", "2", "3", "4"]
        #   ["5", "6", "7", nil]
        #   ["8", "9", "10", nil]
        #
        #   %w(1 2 3 4 5 6 7).in_groups(3, '&nbsp;') {|group| p group}
        #   ["1", "2", "3"]
        #   ["4", "5", "&nbsp;"]
        #   ["6", "7", "&nbsp;"]
        #
        #   %w(1 2 3 4 5 6 7).in_groups(3, false) {|group| p group}
        #   ["1", "2", "3"]
        #   ["4", "5"]
        #   ["6", "7"]
        def in_groups(number, fill_with = nil)
          # size / number gives minor group size;
          # size % number gives how many objects need extra accomodation;
          # each group hold either division or division + 1 items.
          division = size / number
          modulo = size % number

          # create a new array avoiding dup
          groups = []
          start = 0

          number.times do |index|
            length = division + (modulo > 0 && modulo > index ? 1 : 0)
            padding = fill_with != false &&
              modulo > 0 && length == division ? 1 : 0
            groups << slice(start, length).concat([fill_with] * padding)
            start += length
          end

          if block_given?
            groups.each{|g| yield(g) }
          else
            groups
          end
        end

        # Divides the array into one or more subarrays based on a delimiting +value+
        # or the result of an optional block.
        #
        #   [1, 2, 3, 4, 5].split(3)                # => [[1, 2], [4, 5]]
        #   (1..10).to_a.split { |i| i % 3 == 0 }   # => [[1, 2], [4, 5], [7, 8], [10]]
        def split(value = nil)
          using_block = block_given?

          inject([[]]) do |results, element|
            if (using_block && yield(element)) || (value == element)
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
