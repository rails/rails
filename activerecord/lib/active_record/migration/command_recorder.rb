# frozen_string_literal: true

module ActiveRecord
  class Migration
    # = \Migration Command Recorder
    #
    # +ActiveRecord::Migration::CommandRecorder+ records commands done during
    # a migration and knows how to reverse those commands. The CommandRecorder
    # knows how to invert the following commands:
    #
    # * add_column
    # * add_foreign_key
    # * add_check_constraint
    # * add_exclusion_constraint
    # * add_unique_constraint
    # * add_index
    # * add_reference
    # * add_timestamps
    # * change_column_default (must supply a +:from+ and +:to+ option)
    # * change_column_null
    # * change_column_comment (must supply a +:from+ and +:to+ option)
    # * change_table_comment (must supply a +:from+ and +:to+ option)
    # * create_enum
    # * create_join_table
    # * create_virtual_table
    # * create_table
    # * disable_extension
    # * drop_enum (must supply a list of values)
    # * drop_join_table
    # * drop_virtual_table (must supply options)
    # * drop_table (must supply a block)
    # * enable_extension
    # * remove_column (must supply a type)
    # * remove_columns (must supply a +:type+ option)
    # * remove_foreign_key (must supply a second table)
    # * remove_check_constraint
    # * remove_exclusion_constraint
    # * remove_unique_constraint
    # * remove_index
    # * remove_reference
    # * remove_timestamps
    # * rename_column
    # * rename_enum
    # * rename_enum_value (must supply a +:from+ and +:to+ option)
    # * rename_index
    # * rename_table
    class CommandRecorder
      ReversibleAndIrreversibleMethods = [
        :create_table, :create_join_table, :rename_table, :add_column, :remove_column,
        :rename_index, :rename_column, :add_index, :remove_index, :add_timestamps, :remove_timestamps,
        :change_column_default, :add_reference, :remove_reference, :transaction,
        :drop_join_table, :drop_table, :execute_block, :enable_extension, :disable_extension,
        :change_column, :execute, :remove_columns, :change_column_null,
        :add_foreign_key, :remove_foreign_key,
        :change_column_comment, :change_table_comment,
        :add_check_constraint, :remove_check_constraint,
        :add_exclusion_constraint, :remove_exclusion_constraint,
        :add_unique_constraint, :remove_unique_constraint,
        :create_enum, :drop_enum, :rename_enum, :add_enum_value, :rename_enum_value,
        :create_schema, :drop_schema,
        :create_virtual_table, :drop_virtual_table
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
      # If the inverse of a command requires several commands, returns array of commands.
      #
      #   recorder.inverse_of(:remove_columns, [:some_table, :foo, :bar, type: :string])
      #   # => [[:add_column, :some_table, :foo, :string], [:add_column, :some_table, :bar, :string]]
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
        ruby2_keywords(method)
      end
      alias :add_belongs_to :add_reference
      alias :remove_belongs_to :remove_reference

      def change_table(table_name, **options) # :nodoc:
        if delegate.supports_bulk_alter? && options[:bulk]
          recorder = self.class.new(self.delegate)
          recorder.reverting = @reverting
          yield recorder.delegate.update_table_definition(table_name, recorder)
          commands = recorder.commands
          @commands << [:change_table, [table_name], -> t { bulk_change_table(table_name, commands) }]
        else
          yield delegate.update_table_definition(table_name, self)
        end
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
              add_index:         :remove_index,
              add_timestamps:    :remove_timestamps,
              add_reference:     :remove_reference,
              add_foreign_key:   :remove_foreign_key,
              add_check_constraint: :remove_check_constraint,
              add_exclusion_constraint: :remove_exclusion_constraint,
              add_unique_constraint: :remove_unique_constraint,
              enable_extension:  :disable_extension,
              create_enum:       :drop_enum,
              create_schema:     :drop_schema,
              create_virtual_table: :drop_virtual_table
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

        def invert_transaction(args, &block)
          sub_recorder = CommandRecorder.new(delegate)
          sub_recorder.revert(&block)

          invertions_proc = proc {
            sub_recorder.replay(self)
          }

          [:transaction, args, invertions_proc]
        end

        def invert_create_table(args, &block)
          if args.last.is_a?(Hash)
            args.last.delete(:if_not_exists)
          end
          super
        end

        def invert_drop_table(args, &block)
          options = args.extract_options!
          options.delete(:if_exists)

          if args.size > 1
            raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given a single table name."
          end

          if args.size == 1 && options == {} && block == nil
            raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty)."
          end

          args << options unless options.empty?

          super(args, &block)
        end

        def invert_rename_table(args)
          old_name, new_name, options = args
          args = [new_name, old_name]
          args << options if options
          [:rename_table, args]
        end

        def invert_remove_column(args)
          raise ActiveRecord::IrreversibleMigration, "remove_column is only reversible if given a type." if args.size <= 2
          super
        end

        def invert_remove_columns(args)
          unless args[-1].is_a?(Hash) && args[-1].has_key?(:type)
            raise ActiveRecord::IrreversibleMigration, "remove_columns is only reversible if given a type."
          end

          [:add_columns, args]
        end

        def invert_rename_index(args)
          table_name, old_name, new_name = args
          [:rename_index, [table_name, new_name, old_name]]
        end

        def invert_rename_column(args)
          table_name, old_name, new_name = args
          [:rename_column, [table_name, new_name, old_name]]
        end

        def invert_remove_index(args)
          options = args.extract_options!
          table, columns = args

          columns ||= options.delete(:column)

          unless columns
            raise ActiveRecord::IrreversibleMigration, "remove_index is only reversible if given a :column option."
          end

          options.delete(:if_exists)

          args = [table, columns]
          args << options unless options.empty?

          [:add_index, args]
        end

        alias :invert_add_belongs_to :invert_add_reference
        alias :invert_remove_belongs_to :invert_remove_reference

        def invert_change_column_default(args)
          table, column, options = args

          unless options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_column_default is only reversible if given a :from and :to option."
          end

          [:change_column_default, [table, column, from: options[:to], to: options[:from]]]
        end

        def invert_change_column_null(args)
          args[2] = !args[2]
          [:change_column_null, args]
        end

        def invert_add_foreign_key(args)
          args.last.delete(:validate) if args.last.is_a?(Hash)
          super
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
          table, column, options = args

          unless options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_column_comment is only reversible if given a :from and :to option."
          end

          [:change_column_comment, [table, column, from: options[:to], to: options[:from]]]
        end

        def invert_change_table_comment(args)
          table, options = args

          unless options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_table_comment is only reversible if given a :from and :to option."
          end

          [:change_table_comment, [table, from: options[:to], to: options[:from]]]
        end

        def invert_add_check_constraint(args)
          if (options = args.last).is_a?(Hash)
            options.delete(:validate)
            options[:if_exists] = options.delete(:if_not_exists) if options.key?(:if_not_exists)
          end
          super
        end

        def invert_remove_check_constraint(args)
          raise ActiveRecord::IrreversibleMigration, "remove_check_constraint is only reversible if given an expression." if args.size < 2

          if (options = args.last).is_a?(Hash)
            options[:if_not_exists] = options.delete(:if_exists) if options.key?(:if_exists)
          end
          super
        end

        def invert_remove_exclusion_constraint(args)
          raise ActiveRecord::IrreversibleMigration, "remove_exclusion_constraint is only reversible if given an expression." if args.size < 2
          super
        end

        def invert_add_unique_constraint(args)
          options = args.dup.extract_options!

          raise ActiveRecord::IrreversibleMigration, "add_unique_constraint is not reversible if given an using_index." if options[:using_index]
          super
        end

        def invert_remove_unique_constraint(args)
          _table, columns = args.dup.tap(&:extract_options!)

          raise ActiveRecord::IrreversibleMigration, "remove_unique_constraint is only reversible if given an column_name." if columns.blank?
          super
        end

        def invert_drop_enum(args)
          _enum, values = args.dup.tap(&:extract_options!)
          raise ActiveRecord::IrreversibleMigration, "drop_enum is only reversible if given a list of enum values." unless values
          super
        end

        def invert_rename_enum(args)
          name, new_name, = args

          if new_name.is_a?(Hash) && new_name.key?(:to)
            new_name = new_name[:to]
          end

          [:rename_enum, [new_name, name]]
        end

        def invert_rename_enum_value(args)
          type_name, options = args

          unless options.is_a?(Hash) && options.has_key?(:from) && options.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "rename_enum_value is only reversible if given a :from and :to option."
          end

          options[:to], options[:from] = options[:from], options[:to]
          [:rename_enum_value, [type_name, options]]
        end

        def invert_drop_virtual_table(args)
          _enum, values = args.dup.tap(&:extract_options!)
          raise ActiveRecord::IrreversibleMigration, "drop_virtual_table is only reversible if given options." unless values
          super
        end

        def respond_to_missing?(method, _)
          super || delegate.respond_to?(method)
        end

        # Forwards any missing method call to the \target.
        def method_missing(method, ...)
          if delegate.respond_to?(method)
            delegate.public_send(method, ...)
          else
            super
          end
        end
    end
  end
end
