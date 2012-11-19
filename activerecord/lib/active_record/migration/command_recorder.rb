module ActiveRecord
  class Migration
    # <tt>ActiveRecord::Migration::CommandRecorder</tt> records commands done during
    # a migration and knows how to reverse those commands. The CommandRecorder
    # knows how to invert the following commands:
    #
    # * add_column
    # * add_index
    # * add_timestamps
    # * create_table
    # * create_join_table
    # * remove_timestamps
    # * rename_column
    # * rename_index
    # * rename_table
    class CommandRecorder
      include JoinTable

      attr_accessor :commands, :delegate, :reverting

      def initialize(delegate = nil)
        @commands = []
        @delegate = delegate
        @reverting = false
      end

      # While executing the given block, the recorded will be in reverting mode.
      # All commands recorded will end up being recorded reverted
      # and in reverse order.
      # For example:
      #
      #   recorder.revert{ recorder.record(:rename_table, [:old, :new]) }
      #   # same effect as recorder.record(:rename_table, [:new, :old])
      def revert
        @reverting = !@reverting
        previous = @commands
        @commands = []
        yield
      ensure
        @commands = previous.concat(@commands.reverse)
        @reverting = !@reverting
      end

      # record +command+. +command+ should be a method name and arguments.
      # For example:
      #
      #   recorder.record(:method_name, [:arg1, :arg2])
      def record(*command, &block)
        if @reverting
          @commands << inverse_of(*command, &block)
        else
          @commands << (command << block)
        end
      end

      # Returns the inverse of the given command. For example:
      #
      #   recorder.inverse_of(:rename_table, [:old, :new])
      #   # => [:rename_table, [:new, :old]]
      #
      # This method will raise an +IrreversibleMigration+ exception if it cannot
      # invert the +command+.
      def inverse_of(command, args, &block)
        method = :"invert_#{command}"
        raise IrreversibleMigration unless respond_to?(method, true)
        send(method, args, &block)
      end

      def respond_to?(*args) # :nodoc:
        super || delegate.respond_to?(*args)
      end

      [:create_table, :create_join_table, :change_table, :rename_table, :add_column, :remove_column,
        :rename_index, :rename_column, :add_index, :remove_index, :add_timestamps, :remove_timestamps,
        :change_column, :change_column_default, :add_reference, :remove_reference, :transaction,
        :drop_join_table, :drop_table, :remove_columns,
      ].each do |method|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)          # def create_table(*args, &block)
            record(:"#{method}", args, &block)  #   record(:create_table, args, &block)
          end                                   # end
        EOV
      end
      alias :add_belongs_to :add_reference
      alias :remove_belongs_to :remove_reference

      private

      def invert_transaction(args, &block)
        [:transaction, args, block]
      end

      def invert_create_table(args, &block)
        [:drop_table, args, block]
      end

      def invert_drop_table(args, &block)
        if args.size == 1 && block == nil
          raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty)."
        end
        [:create_table, args, block]
      end

      def invert_create_join_table(args, &block)
        [:drop_join_table, args, block]
      end

      def invert_drop_join_table(args, &block)
        [:create_join_table, args, block]
      end

      def invert_rename_table(args)
        [:rename_table, args.reverse]
      end

      def invert_add_column(args)
        [:remove_column, args]
      end

      def invert_remove_column(args)
        raise ActiveRecord::IrreversibleMigration, "remove_column is only reversible if given a type." if args.size <= 2
        [:add_column, args]
      end

      def invert_rename_index(args)
        [:rename_index, [args.first] + args.last(2).reverse]
      end

      def invert_rename_column(args)
        [:rename_column, [args.first] + args.last(2).reverse]
      end

      def invert_add_index(args)
        table, columns, options = *args
        index_name = options.try(:[], :name)
        options_hash =  index_name ? {:name => index_name} : {:column => columns}
        [:remove_index, [table, options_hash]]
      end

      def invert_remove_timestamps(args)
        [:add_timestamps, args]
      end

      def invert_add_timestamps(args)
        [:remove_timestamps, args]
      end

      def invert_add_reference(args)
        [:remove_reference, args]
      end
      alias :invert_add_belongs_to :invert_add_reference

      def invert_remove_reference(args)
        [:add_reference, args]
      end
      alias :invert_remove_belongs_to :invert_remove_reference

      # Forwards any missing method call to the \target.
      def method_missing(method, *args, &block)
        @delegate.send(method, *args, &block)
      rescue NoMethodError => e
        raise e, e.message.sub(/ for #<.*$/, " via proxy for #{@delegate}")
      end
    end
  end
end
