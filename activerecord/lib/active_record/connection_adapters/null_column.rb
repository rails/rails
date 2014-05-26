module ActiveRecord
  module ConnectionAdapters # :nodoc:
    # NullColumn is an implementation of the NullObject pattern that
    # allows the quoting modules in the ConnectionAdapters to avoid
    # checking whether a column was passed in or not. It implements
    # just enough functionality to allow the default behavior of
    # quoting to occur.
    class NullColumn # :nodoc:
      def type
        :null
      end

      def limit
        nil
      end

      def precision
        nil
      end

      def scale
        nil
      end
    end
  end
end
