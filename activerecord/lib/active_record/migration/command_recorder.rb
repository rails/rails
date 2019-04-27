# frozen_string_literal: true

module ActiveRecord
  class Migration
    # <tt>ActiveRecord::Migration::CommandRecorder</tt> records commands done during
    # a migration and knows how to reverse those commands. The CommandRecorder
    # knows how to invert the following commands:
    #
    # * add_column
    # * add_foreign_key
    # * add_index
    # * add_reference
    # * add_timestamps
    # * change_column
    # * change_column_default (must supply a :from and :to option)
    # * change_column_null
    # * change_column_comment (must supply a :from and :to option)
    # * change_table_comment (must supply a :from and :to option)
    # * create_join_table
    # * create_table
    # * disable_extension
    # * drop_join_table
    # * drop_table (must supply a block)
    # * enable_extension
    # * remove_column (must supply a type)
    # * remove_columns (must specify at least one column name or more)
    # * remove_foreign_key (must supply a second table)
    # * remove_index
    # * remove_reference
    # * remove_timestamps
    # * rename_column
    # * rename_index
    # * rename_table
    class CommandRecorder
      ReversibleAndIrreversibleMethods = [:create_table, :create_join_table, :rename_table, :add_column, :remove_column,
        :rename_index, :rename_column, :add_index, :remove_index, :add_timestamps, :remove_timestamps,
        :change_column_default, :add_reference, :remove_reference, :transaction,
        :drop_join_table, :drop_table, :execute_block, :enable_extension, :disable_extension,
        :change_column, :execute, :remove_columns, :change_column_null,
        :add_foreign_key, :remove_foreign_key,
        :change_column_comment, :change_table_comment
      ]
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

      # Record +command+. +command+ should be a method name and arguments.
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
        raise IrreversibleMigration, <<~MSG unless respond_to?(method, true)
          This migration uses #{command}, which is not automatically reversible.
          To make the migration reversible you can either:
          1. Define #up and #down methods in place of the #change method.
          2. Use the #reversible method to define reversible behavior.
        MSG
        send(method, args, &block)
      end

      ReversibleAndIrreversibleMethods.each do |method|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{method}(*args, &block)          # def create_table(*args, &block)
            record(:"#{method}", args, &block)  #   record(:create_table, args, &block)
          end                                   # end
        EOV
      end
      alias :add_belongs_to :add_reference
      alias :remove_belongs_to :remove_reference

      def change_table(table_name, options = {}) # :nodoc:
        yield delegate.update_table_definition(table_name, self)
      end

      def replay(migration)
        commands.each do |cmd, args, block|
          migration.send(cmd, *args, &block)
        end
      end

      private

        module StraightReversions # :nodoc:
          private
            {
              execute_block:     :execute_block,
              create_table:      :drop_table,
              create_join_table: :drop_join_table,
              add_column:        :remove_column,
              add_timestamps:    :remove_timestamps,
              add_reference:     :remove_reference,
              enable_extension:  :disable_extension
            }.each do |cmd, inv|
              [[inv, cmd], [cmd, inv]].uniq.each do |method, inverse|
                class_eval <<-EOV, __FILE__, __LINE__ + 1
                  def invert_#{method}(args, &block)    # def invert_create_table(args, &block)
                    [:#{inverse}, args, block]          #   [:drop_table, args, block]
                  end                                   # end
                EOV
              end
            end
        end

        include StraightReversions

        def invert_transaction(args)
          sub_recorder = CommandRecorder.new(delegate)
          sub_recorder.revert { yield }

          invertions_proc = proc {
            sub_recorder.replay(self)
          }

          [:transaction, args, invertions_proc]
        end

        def invert_drop_table(args, &block)
          if args.size == 1 && block == nil
            raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty)."
          end
          super
        end

        def invert_rename_table(args)
          [:rename_table, args.reverse]
        end

        def invert_remove_column(args)
          raise ActiveRecord::IrreversibleMigration, "remove_column is only reversible if given a type." if args.size <= 2
          super
        end

        def invert_rename_index(args)
          [:rename_index, [args.first] + args.last(2).reverse]
        end

        def invert_rename_column(args)
          [:rename_column, [args.first] + args.last(2).reverse]
        end

        def invert_add_index(args)
          table, columns, options = *args
          options ||= {}

          options_hash = options.slice(:name, :algorithm)
          options_hash[:column] = columns if !options_hash[:name]

          [:remove_index, [table, options_hash]]
        end

        def invert_remove_index(args)
          table, options_or_column = *args
          if (options = options_or_column).is_a?(Hash)
            unless options[:column]
              raise ActiveRecord::IrreversibleMigration, "remove_index is only reversible if given a :column option."
            end
            options = options.dup
            [:add_index, [table, options.delete(:column), options]]
          elsif (column = options_or_column).present?
            [:add_index, [table, column]]
          end
        end

        alias :invert_add_belongs_to :invert_add_reference
        alias :invert_remove_belongs_to :invert_remove_reference

        def invert_change_column_default(args)
          table, column, options = *args

          unless options && options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_column_default is only reversible if given a :from and :to option."
          end

          [:change_column_default, [table, column, from: options[:to], to: options[:from]]]
        end

        def invert_change_column_null(args)
          args[2] = !args[2]
          [:change_column_null, args]
        end

        def invert_add_foreign_key(args)
          from_table, to_table, add_options = args
          add_options ||= {}

          if add_options[:name]
            options = { name: add_options[:name] }
          elsif add_options[:column]
            options = { column: add_options[:column] }
          else
            options = to_table
          end

          [:remove_foreign_key, [from_table, options]]
        end

        def invert_remove_foreign_key(args)
          options = args.extract_options!
          from_table, to_table = args

          to_table ||= options.delete(:to_table)

          raise ActiveRecord::IrreversibleMigration, "remove_foreign_key is only reversible if given a second table" if to_table.nil?

          reversed_args = [from_table, to_table]
          reversed_args << options unless options.empty?

          [:add_foreign_key, reversed_args]
        end

        def invert_change_column_comment(args)
          table, column, options = *args

          unless options && options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_column_comment is only reversible if given a :from and :to option."
          end

          [:change_column_comment, [table, column, from: options[:to], to: options[:from]]]
        end

        def invert_change_table_comment(args)
          table, options = *args

          unless options && options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_table_comment is only reversible if given a :from and :to option."
          end

          [:change_table_comment, [table, from: options[:to], to: options[:from]]]
        end

        def respond_to_missing?(method, _)
          super || delegate.respond_to?(method)
        end

        # Forwards any missing method call to the \target.
        def method_missing(method, *args, &block)
          if delegate.respond_to?(method)
            delegate.public_send(method, *args, &block)
          else
            super
          end
        end
    end
  end
end
