module ActiveRecord
  class Migration
    # ActiveRecord::Migration::CommandRecorder records commands done during
    # a migration and knows how to reverse those commands.  The CommandRecorder
    # knows how to invert the following commands:
    #
    # * add_column
    # * add_index
    # * add_timestamp
    # * create_table
    # * remove_timestamps
    # * rename_column
    # * rename_index
    # * rename_table
    class CommandRecorder
      attr_accessor :commands, :delegate

      def initialize(delegate = nil)
        @commands = []
        @delegate = delegate
      end

      # record +command+.  +command+ should be a method name and arguments.
      # For example:
      #
      #   recorder.record(:method_name, [:arg1, arg2])
      def record(*command)
        @commands << command
      end

      # Returns a list that represents commands that are the inverse of the
      # commands stored in +commands+.  For example:
      #
      #   recorder.record(:rename_table, [:old, :new])
      #   recorder.inverse # => [:rename_table, [:new, :old]]
      #
      # This method will raise an IrreversibleMigration exception if it cannot
      # invert the +commands+.
      def inverse
        @commands.reverse.map { |name, args|
          method = :"invert_#{name}"
          raise IrreversibleMigration unless respond_to?(method, true)
          __send__(method, args)
        }
      end

      def respond_to?(*args) # :nodoc:
        super || delegate.respond_to?(*args)
      end

      def send(method, *args) # :nodoc:
        return super unless respond_to?(method)
        record(method, args)
      end

      private
      def invert_create_table(args)
        [:drop_table, args]
      end

      def invert_rename_table(args)
        [:rename_table, args.reverse]
      end

      def invert_add_column(args)
        [:remove_column, args.first(2)]
      end

      def invert_rename_index(args)
        [:rename_index, args.reverse]
      end

      def invert_rename_column(args)
        [:rename_column, [args.first] + args.last(2).reverse]
      end

      def invert_add_index(args)
        table, columns, _ = *args
        [:remove_index, [table, {:column => columns}]]
      end

      def invert_remove_timestamps(args)
        [:add_timestamps, args]
      end

      def invert_add_timestamps(args)
        [:remove_timestamps, args]
      end
    end
  end
end
