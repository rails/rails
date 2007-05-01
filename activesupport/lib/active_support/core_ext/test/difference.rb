
module Test #:nodoc:
  module Unit #:nodoc:
    class TestCase #:nodoc:
      
      # Test difference between the return value of method on object for duration of the block
      def assert_difference(objects, method = nil, difference = 1)
        objects = [objects].flatten
        initial_values = objects.inject([]) { |sum,obj| sum << obj.send(method) }
        yield
        if difference.nil?
          objects.each_with_index { |obj,i|
            assert_not_equal initial_values[i], obj.send(method), "#{obj}##{method}"
          }
        else
          objects.each_with_index { |obj,i|
            assert_equal initial_values[i] + difference, obj.send(method), "#{obj}##{method}"
          }
        end
      end

      # Test absence of difference between the return value of method on object for duration of the block
      def assert_no_difference(objects, method = nil, &block)
        assert_difference objects, method, 0, &block
      end

    end
  end
end
