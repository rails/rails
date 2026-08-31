# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module ColumnMethods
        extend ActiveSupport::Concern
        extend ConnectionAdapters::ColumnMethods::ClassMethods

        ##
        # :method: blob
        # :call-seq: blob(*names, **options)

        ##
        # :method: tinyblob
        # :call-seq: tinyblob(*names, **options)

        ##
        # :method: mediumblob
        # :call-seq: mediumblob(*names, **options)

        ##
        # :method: longblob
        # :call-seq: longblob(*names, **options)

        ##
        # :method: tinytext
        # :call-seq: tinytext(*names, **options)

        ##
        # :method: mediumtext
        # :call-seq: mediumtext(*names, **options)

        ##
        # :method: longtext
        # :call-seq: longtext(*names, **options)

        ##
        # :method: unsigned_integer
        # :call-seq: unsigned_integer(*names, **options)

        ##
        # :method: unsigned_bigint
        # :call-seq: unsigned_bigint(*names, **options)

        define_column_methods :blob, :tinyblob, :mediumblob, :longblob,
          :tinytext, :mediumtext, :longtext, :unsigned_integer, :unsigned_bigint
      end

      # = Active Record MySQL Adapter \Index Definition
      class IndexDefinition < ActiveRecord::ConnectionAdapters::IndexDefinition # :nodoc:
        attr_accessor :enabled

        def initialize(*args, enabled: true, **kwargs)
          @enabled = enabled
          super(*args, **kwargs)
        end

        def defined_for?(columns = nil, name: nil, unique: nil, valid: nil, include: nil, nulls_not_distinct: nil, enabled: nil, **options)
          super(columns, name:, unique:, valid:, include:, nulls_not_distinct:, **options) &&
            (enabled.nil? || self.enabled == enabled)
        end

        def disabled?
          !@enabled
        end
      end

      # = Active Record MySQL Adapter \Table Definition
      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        attr_reader :charset, :collation

        def initialize(conn, name, charset: nil, collation: nil, **)
          super
          @charset = charset
          @collation = collation
        end

        def new_column_definition(name, type, **options) # :nodoc:
          case type
          when :virtual
            type = options[:type]
          when :primary_key
            type = :integer
            options[:limit] ||= 8
            options[:primary_key] = true
          when /\Aunsigned_(?<type>.+)\z/
            type = $~[:type].to_sym
            options[:unsigned] = true
          end

          super
        end

        private
          def valid_column_definition_options
            super + [:auto_increment, :charset, :as, :size, :unsigned, :first, :after, :type, :stored]
          end

          def aliased_types(name, fallback)
            fallback
          end

          def integer_like_primary_key_type(type, options)
            unless options[:auto_increment] == false
              options[:auto_increment] = true
            end

            type
          end
      end

      AddIndex = Data.define(:index) # :nodoc:
      DropIndex = Data.define(:name) # :nodoc:

      # = Active Record MySQL Adapter Alter \Table
      class AlterTable < ActiveRecord::ConnectionAdapters::AlterTable # :nodoc:
        COMBINABLE_COMMANDS = (superclass::COMBINABLE_COMMANDS + %i[change_column rename_column add_index remove_index]).freeze

        attr_reader :algorithm, :lock

        def algorithm=(value)
          @algorithm = @td.conn.index_algorithm(value) if value
        end

        def lock=(value)
          @lock = @td.conn.lock_clause(value) if value
        end

        def add_column(column_name, type, **options)
          extract_algorithm_and_lock!(options)
          super
        end

        def remove_column(column_name, _type = nil, **options)
          extract_algorithm_and_lock!(options)
          # MySQL rejects `DROP COLUMN` on a column referenced by a foreign key,
          # so drop the FK in the same `ALTER TABLE` statement as the column.
          if fk = @td.conn.send(:foreign_key_for, name, column: column_name)
            @operations << DropForeignKey.new(fk.name)
          end
          super
        end

        def add_index(column_name, **options)
          extract_algorithm_and_lock!(options)
          index, _ = @td.conn.add_index_options(name, column_name, **options)
          @operations << AddIndex.new(index)
        end

        def remove_index(column_name = nil, **options)
          extract_algorithm_and_lock!(options)
          index_name = @td.conn.send(:index_name_for_remove, name, column_name, options)
          @operations << DropIndex.new(index_name)
        end

        def change_column(column_name, type, **options)
          extract_algorithm_and_lock!(options)
          conn = @td.conn
          column = conn.send(:column_for, name, column_name)
          type ||= column.sql_type

          unless options.key?(:default)
            options[:default] = if column.default_function
              -> { column.default_function }
            else
              column.default
            end
          end

          unless options.key?(:null)
            options[:null] = column.null
          end

          unless options.key?(:comment)
            options[:comment] = column.comment
          end

          if options[:collation] == :no_collation
            options.delete(:collation)
          else
            options[:collation] ||= column.collation if conn.send(:text_type?, type)
          end

          unless options.key?(:auto_increment)
            options[:auto_increment] = column.auto_increment?
          end

          cd = @td.new_column_definition(column.name, type, **options)
          @operations << ChangeColumnDefinition.new(cd, column.name)
        end

        def rename_column(from_name, to_name, **options)
          extract_algorithm_and_lock!(options)
          conn = @td.conn
          if conn.send(:supports_rename_column?)
            super(from_name, to_name)
          else
            column = conn.send(:column_for, name, from_name)
            column_options = {
              default: column.default,
              null: column.null,
              auto_increment: column.auto_increment?,
              comment: column.comment
            }
            current_type = conn.query_one("SHOW COLUMNS FROM #{conn.quote_table_name(name)} LIKE #{conn.quote(from_name)}")["Type"]
            cd = @td.new_column_definition(to_name, current_type, **column_options)
            @operations << ChangeColumnDefinition.new(cd, column.name)
          end
        end

        private
          def extract_algorithm_and_lock!(options)
            self.algorithm = options.delete(:algorithm)
            self.lock = options.delete(:lock)
          end
      end

      # = Active Record MySQL Adapter \Table
      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods

        # Enables an index to be used by query optimizers.
        #
        #   t.enable_index(:email)
        #
        # Note: only supported by MySQL version 8.0.0 and greater, and MariaDB version 10.6.0 and greater.
        #
        # See {connection.enable_index}[rdoc-ref:SchemaStatements#enable_index]
        def enable_index(index_name)
          @base.enable_index(name, index_name)
        end

        # Disables an index not to be used by query optimizers.
        #
        #   t.disable_index(:email)
        #
        # Note: only supported by MySQL version 8.0.0 and greater, and MariaDB version 10.6.0 and greater.
        #
        # See {connection.disable_index}[rdoc-ref:SchemaStatements#disable_index]
        def disable_index(index_name)
          @base.disable_index(name, index_name)
        end
      end
    end
  end
end
