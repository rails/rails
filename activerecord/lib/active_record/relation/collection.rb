module ActiveRecord
  class Relation
    module Collection
      # Returns true if there are no records.
      def empty?
        if loaded?
          @records.empty?
        else
          c = count(:all)
          c.respond_to?(:zero?) ? c.zero? : c.empty?
        end
      end

      # Returns size of the records.
      def size
        loaded? ? @records.length : count(:all)
      end

      # Returns true if there are no records.
      def none?
        if block_given?
          to_a.none? { |*block_args| yield(*block_args) }
        else
          empty?
        end
      end

      # Returns true if there are any records.
      def any?
        if block_given?
          to_a.any? { |*block_args| yield(*block_args) }
        else
          !empty?
        end
      end

      # Returns true if there is exactly one record.
      def one?
        if block_given?
          to_a.one? { |*block_args| yield(*block_args) }
        else
          limit_value ? to_a.one? : size == 1
        end
      end

      # Returns true if there is more than one record.
      def many?
        if block_given?
          to_a.many? { |*block_args| yield(*block_args) }
        else
          limit_value ? to_a.many? : size > 1
        end
      end

      # Converts relation objects to Array.
      def to_a
        load
        @records
      end

      # Returns true if relation is blank.
      def blank?
        to_a.blank?
      end
    end
  end
end
