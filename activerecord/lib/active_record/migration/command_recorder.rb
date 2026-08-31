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
    # * enable_index
    # * disable_index
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
        :create_virtual_table, :drop_virtual_table,
        :enable_index, :disable_index
      ].freeze

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
      #   recorder.revert { recorder.rename_table(:old, :new) }
      #   # same effect as recorder.rename_table(:new, :old)
      def revert
        @reverting = !@reverting
        previous = @commands
        @commands = []
        yield
      ensure
        @commands = previous.concat(@commands.reverse)
        @reverting = !@reverting
      end

      ReversibleAndIrreversibleMethods.each do |method|
        class_eval <<-EOV, __FILE__, __LINE__ + 1
          def #{method}(*args, **kwargs, &block)        # def create_table(*args, **kwargs, &block)
            record(:"#{method}", args, kwargs, &block)  #   record(:create_table, args, kwargs, &block)
          end                                           # end
        EOV
      end
      alias :add_belongs_to :add_reference
      alias :remove_belongs_to :remove_reference

      def change_table(table_name, **options) # :nodoc:
        if delegate.supports_bulk_alter? && options[:bulk]
          recorder = self.class.new(self.delegate)
          recorder.reverting = @reverting
          yield recorder.delegate.update_table_definition(table_name, recorder)
          commands = recorder.commands
          @commands << [:change_table, [table_name], {}, -> t { bulk_change_table(t.name, commands.reverse) }]
        else
          yield delegate.update_table_definition(table_name, self)
        end
      end

      def replay(migration)
        commands.each do |cmd, args, kwargs, block|
          migration.send(cmd, *args, **kwargs, &block)
        end
      end

      private
        def record(command, args, kwargs, &block)
          if @reverting
            @commands << inverse_of(command, args, kwargs, &block)
          else
            @commands << [command, args, kwargs, block]
          end
        end

        def inverse_of(command, args, kwargs, &block)
          method = :"invert_#{command}"
          raise IrreversibleMigration, <<~MSG unless respond_to?(method, true)
            This migration uses #{command}, which is not automatically reversible.
            To make the migration reversible you can either:
            1. Define #up and #down methods in place of the #change method.
            2. Use the #reversible method to define reversible behavior.
          MSG
          send(method, args, kwargs, &block)
        end

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
                  def invert_#{method}(args, kwargs, &block)  # def invert_create_table(args, kwargs, &block)
                    [:#{inverse}, args, kwargs, block]        #   [:drop_table, args, kwargs, block]
                  end                                         # end
                EOV
              end
            end
        end

        include StraightReversions

        def invert_enable_index(args, kwargs)
          table_name, index_name = args
          [:disable_index, [table_name, index_name], kwargs]
        end

        def invert_disable_index(args, kwargs)
          table_name, index_name = args
          [:enable_index, [table_name, index_name], kwargs]
        end

        def invert_transaction(args, kwargs, &block)
          sub_recorder = CommandRecorder.new(delegate)
          sub_recorder.revert(&block)

          invertions_proc = proc {
            sub_recorder.replay(self)
          }

          [:transaction, args, kwargs, invertions_proc]
        end

        def invert_create_table(args, kwargs, &block)
          kwargs.delete(:if_not_exists)
          super
        end

        def invert_drop_table(args, kwargs, &block)
          kwargs.delete(:if_exists)

          if args.size > 1
            raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given a single table name."
          end

          if args.size == 1 && kwargs.empty? && block == nil
            raise ActiveRecord::IrreversibleMigration, "To avoid mistakes, drop_table is only reversible if given options or a block (can be empty)."
          end

          super
        end

        def invert_rename_table(args, kwargs)
          old_name, new_name = args
          [:rename_table, [new_name, old_name], kwargs]
        end

        def invert_remove_column(args, kwargs)
          if args.size < 3
            raise ActiveRecord::IrreversibleMigration, "remove_column is only reversible if given a type."
          end
          kwargs[:if_not_exists] = kwargs.delete(:if_exists) if kwargs.key?(:if_exists)
          super
        end

        def invert_remove_columns(args, kwargs)
          unless kwargs.key?(:type)
            raise ActiveRecord::IrreversibleMigration, "remove_columns is only reversible if given a type."
          end

          [:add_columns, args, kwargs]
        end

        def invert_rename_index(args, kwargs)
          table_name, old_name, new_name = args
          [:rename_index, [table_name, new_name, old_name], kwargs]
        end

        def invert_rename_column(args, kwargs)
          table_name, old_name, new_name = args
          [:rename_column, [table_name, new_name, old_name], kwargs]
        end

        def invert_remove_index(args, kwargs)
          table, columns = args

          columns ||= kwargs.delete(:column)

          unless columns
            raise ActiveRecord::IrreversibleMigration, "remove_index is only reversible if given a :column option."
          end

          kwargs[:if_not_exists] = kwargs.delete(:if_exists) if kwargs.key?(:if_exists)

          [:add_index, [table, columns], kwargs]
        end

        def invert_add_reference(args, kwargs)
          kwargs[:if_exists] = kwargs.delete(:if_not_exists) if kwargs.key?(:if_not_exists)
          super
        end

        def invert_remove_reference(args, kwargs)
          kwargs[:if_not_exists] = kwargs.delete(:if_exists) if kwargs.key?(:if_exists)
          super
        end

        alias :invert_add_belongs_to :invert_add_reference
        alias :invert_remove_belongs_to :invert_remove_reference

        def invert_change_column_default(args, kwargs)
          unless kwargs.has_key?(:from) && kwargs.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_column_default is only reversible if given a :from and :to option."
          end

          [:change_column_default, args, { from: kwargs[:to], to: kwargs[:from] }]
        end

        def invert_change_column_null(args, kwargs)
          table_name, column_name, null, default = args
          [:change_column_null, [table_name, column_name, !null, default], kwargs]
        end

        def invert_add_column(args, kwargs)
          kwargs[:if_exists] = kwargs.delete(:if_not_exists) if kwargs.key?(:if_not_exists)
          super
        end

        def invert_add_index(args, kwargs)
          kwargs[:if_exists] = kwargs.delete(:if_not_exists) if kwargs.key?(:if_not_exists)
          super
        end

        def invert_add_foreign_key(args, kwargs)
          kwargs.delete(:validate)
          kwargs[:if_exists] = kwargs.delete(:if_not_exists) if kwargs.key?(:if_not_exists)
          super
        end

        def invert_remove_foreign_key(args, kwargs)
          from_table, to_table = args

          to_table ||= kwargs.delete(:to_table)
          kwargs[:if_not_exists] = kwargs.delete(:if_exists) if kwargs.key?(:if_exists)

          raise ActiveRecord::IrreversibleMigration, "remove_foreign_key is only reversible if given a second table" if to_table.nil?

          [:add_foreign_key, [from_table, to_table], kwargs]
        end

        def invert_change_column_comment(args, kwargs)
          unless kwargs.has_key?(:from) && kwargs.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_column_comment is only reversible if given a :from and :to option."
          end

          [:change_column_comment, args, { from: kwargs[:to], to: kwargs[:from] }]
        end

        def invert_change_table_comment(args, kwargs)
          unless kwargs.has_key?(:from) && kwargs.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "change_table_comment is only reversible if given a :from and :to option."
          end

          [:change_table_comment, args, { from: kwargs[:to], to: kwargs[:from] }]
        end

        def invert_add_check_constraint(args, kwargs)
          kwargs.delete(:validate)
          kwargs[:if_exists] = kwargs.delete(:if_not_exists) if kwargs.key?(:if_not_exists)
          super
        end

        def invert_remove_check_constraint(args, kwargs)
          raise ActiveRecord::IrreversibleMigration, "remove_check_constraint is only reversible if given an expression." if args.size < 2

          kwargs[:if_not_exists] = kwargs.delete(:if_exists) if kwargs.key?(:if_exists)
          super
        end

        def invert_remove_exclusion_constraint(args, kwargs)
          raise ActiveRecord::IrreversibleMigration, "remove_exclusion_constraint is only reversible if given an expression." if args.size < 2
          super
        end

        def invert_add_unique_constraint(args, kwargs)
          raise ActiveRecord::IrreversibleMigration, "add_unique_constraint is not reversible if given a using_index." if kwargs[:using_index]
          super
        end

        def invert_remove_unique_constraint(args, kwargs)
          _table, columns = args
          raise ActiveRecord::IrreversibleMigration, "remove_unique_constraint is only reversible if given a column_name." if columns.blank?
          super
        end

        def invert_drop_enum(args, kwargs)
          _enum, values = args
          raise ActiveRecord::IrreversibleMigration, "drop_enum is only reversible if given a list of enum values." unless values
          super
        end

        def invert_rename_enum(args, kwargs)
          old_name, new_name = args
          new_name ||= kwargs.delete(:to)
          [:rename_enum, [new_name, old_name], kwargs]
        end

        def invert_rename_enum_value(args, kwargs)
          unless kwargs.has_key?(:from) && kwargs.has_key?(:to)
            raise ActiveRecord::IrreversibleMigration, "rename_enum_value is only reversible if given a :from and :to option."
          end

          [:rename_enum_value, args, { from: kwargs[:to], to: kwargs[:from] }]
        end

        def invert_drop_virtual_table(args, kwargs)
          _table_name, _module_name, values = args
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
