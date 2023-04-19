# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module ColumnMethods
        extend ActiveSupport::Concern

        # Defines the primary key field.
        # Use of the native PostgreSQL UUID type is supported, and can be used
        # by defining your tables as such:
        #
        #   create_table :stuffs, id: :uuid do |t|
        #     t.string :content
        #     t.timestamps
        #   end
        #
        # By default, this will use the <tt>gen_random_uuid()</tt> function from the
        # +pgcrypto+ extension. As that extension is only available in
        # PostgreSQL 9.4+, for earlier versions an explicit default can be set
        # to use <tt>uuid_generate_v4()</tt> from the +uuid-ossp+ extension instead:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: "uuid_generate_v4()"
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # To enable the appropriate extension, which is a requirement, use
        # the +enable_extension+ method in your migrations.
        #
        # To use a UUID primary key without any of the extensions, set the
        # +:default+ option to +nil+:
        #
        #   create_table :stuffs, id: false do |t|
        #     t.primary_key :id, :uuid, default: nil
        #     t.uuid :foo_id
        #     t.timestamps
        #   end
        #
        # You may also pass a custom stored procedure that returns a UUID or use a
        # different UUID generation function from another library.
        #
        # Note that setting the UUID primary key default value to +nil+ will
        # require you to assure that you always provide a UUID value before saving
        # a record (as primary keys cannot be +nil+). This might be done via the
        # +SecureRandom.uuid+ method and a +before_save+ callback, for instance.
        def primary_key(name, type = :primary_key, **options)
          if type == :uuid
            options[:default] = options.fetch(:default, "gen_random_uuid()")
          end

          super
        end

        ##
        # :method: bigserial
        # :call-seq: bigserial(*names, **options)

        ##
        # :method: bit
        # :call-seq: bit(*names, **options)

        ##
        # :method: bit_varying
        # :call-seq: bit_varying(*names, **options)

        ##
        # :method: cidr
        # :call-seq: cidr(*names, **options)

        ##
        # :method: citext
        # :call-seq: citext(*names, **options)

        ##
        # :method: daterange
        # :call-seq: daterange(*names, **options)

        ##
        # :method: hstore
        # :call-seq: hstore(*names, **options)

        ##
        # :method: inet
        # :call-seq: inet(*names, **options)

        ##
        # :method: interval
        # :call-seq: interval(*names, **options)

        ##
        # :method: int4range
        # :call-seq: int4range(*names, **options)

        ##
        # :method: int8range
        # :call-seq: int8range(*names, **options)

        ##
        # :method: jsonb
        # :call-seq: jsonb(*names, **options)

        ##
        # :method: ltree
        # :call-seq: ltree(*names, **options)

        ##
        # :method: macaddr
        # :call-seq: macaddr(*names, **options)

        ##
        # :method: money
        # :call-seq: money(*names, **options)

        ##
        # :method: numrange
        # :call-seq: numrange(*names, **options)

        ##
        # :method: oid
        # :call-seq: oid(*names, **options)

        ##
        # :method: point
        # :call-seq: point(*names, **options)

        ##
        # :method: line
        # :call-seq: line(*names, **options)

        ##
        # :method: lseg
        # :call-seq: lseg(*names, **options)

        ##
        # :method: box
        # :call-seq: box(*names, **options)

        ##
        # :method: path
        # :call-seq: path(*names, **options)

        ##
        # :method: polygon
        # :call-seq: polygon(*names, **options)

        ##
        # :method: circle
        # :call-seq: circle(*names, **options)

        ##
        # :method: serial
        # :call-seq: serial(*names, **options)

        ##
        # :method: tsrange
        # :call-seq: tsrange(*names, **options)

        ##
        # :method: tstzrange
        # :call-seq: tstzrange(*names, **options)

        ##
        # :method: tsvector
        # :call-seq: tsvector(*names, **options)

        ##
        # :method: uuid
        # :call-seq: uuid(*names, **options)

        ##
        # :method: xml
        # :call-seq: xml(*names, **options)

        ##
        # :method: timestamptz
        # :call-seq: timestamptz(*names, **options)

        ##
        # :method: enum
        # :call-seq: enum(*names, **options)

        included do
          define_column_methods :bigserial, :bit, :bit_varying, :cidr, :citext, :daterange,
            :hstore, :inet, :interval, :int4range, :int8range, :jsonb, :ltree, :macaddr,
            :money, :numrange, :oid, :point, :line, :lseg, :box, :path, :polygon, :circle,
            :serial, :tsrange, :tstzrange, :tsvector, :uuid, :xml, :timestamptz, :enum
        end
      end

      ExclusionConstraintDefinition = Struct.new(:table_name, :expression, :options) do
        def name
          options[:name]
        end

        def using
          options[:using]
        end

        def where
          options[:where]
        end

        def deferrable
          options[:deferrable]
        end

        def export_name_on_schema_dump?
          !ActiveRecord::SchemaDumper.excl_ignore_pattern.match?(name) if name
        end
      end

      UniqueKeyDefinition = Struct.new(:table_name, :columns, :options) do
        def name
          options[:name]
        end

        def deferrable
          options[:deferrable]
        end

        def using_index
          options[:using_index]
        end

        def export_name_on_schema_dump?
          !ActiveRecord::SchemaDumper.unique_ignore_pattern.match?(name) if name
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

        attr_reader :exclusion_constraints, :unique_keys, :unlogged

        def initialize(*, **)
          super
          @exclusion_constraints = []
          @unique_keys = []
          @unlogged = ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.create_unlogged_tables
        end

        def exclusion_constraint(expression, **options)
          exclusion_constraints << new_exclusion_constraint_definition(expression, options)
        end

        def unique_key(column_name, **options)
          unique_keys << new_unique_key_definition(column_name, options)
        end

        def new_exclusion_constraint_definition(expression, options) # :nodoc:
          options = @conn.exclusion_constraint_options(name, expression, options)
          ExclusionConstraintDefinition.new(name, expression, options)
        end

        def new_unique_key_definition(column_name, options) # :nodoc:
          options = @conn.unique_key_options(name, column_name, options)
          UniqueKeyDefinition.new(name, column_name, options)
        end

        def new_column_definition(name, type, **options) # :nodoc:
          case type
          when :virtual
            type = options[:type]
          end

          super
        end

        private
          def valid_column_definition_options
            super + [:array, :using, :cast_as, :as, :type, :enum_type, :stored]
          end

          def aliased_types(name, fallback)
            fallback
          end

          def integer_like_primary_key_type(type, options)
            if type == :bigint || options[:limit] == 8
              :bigserial
            else
              :serial
            end
          end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods

        # Adds an exclusion constraint.
        #
        #  t.exclusion_constraint("price WITH =, availability_range WITH &&", using: :gist, name: "price_check")
        #
        # See {connection.add_exclusion_constraint}[rdoc-ref:SchemaStatements#add_exclusion_constraint]
        def exclusion_constraint(*args)
          @base.add_exclusion_constraint(name, *args)
        end

        # Removes the given exclusion constraint from the table.
        #
        #  t.remove_exclusion_constraint(name: "price_check")
        #
        # See {connection.remove_exclusion_constraint}[rdoc-ref:SchemaStatements#remove_exclusion_constraint]
        def remove_exclusion_constraint(*args)
          @base.remove_exclusion_constraint(name, *args)
        end

        # Adds an unique constraint.
        #
        #  t.unique_key(:position, name: 'unique_position', deferrable: :deferred)
        #
        # See {connection.add_unique_key}[rdoc-ref:SchemaStatements#add_unique_key]
        def unique_key(*args)
          @base.add_unique_key(name, *args)
        end

        # Removes the given unique constraint from the table.
        #
        #  t.remove_unique_key(name: "unique_position")
        #
        # See {connection.remove_unique_key}[rdoc-ref:SchemaStatements#remove_unique_key]
        def remove_unique_key(*args)
          @base.remove_unique_key(name, *args)
        end
      end

      class AlterTable < ActiveRecord::ConnectionAdapters::AlterTable
        attr_reader :constraint_validations, :exclusion_constraint_adds, :exclusion_constraint_drops, :unique_key_adds, :unique_key_drops

        def initialize(td)
          super
          @constraint_validations = []
          @exclusion_constraint_adds = []
          @exclusion_constraint_drops = []
          @unique_key_adds = []
          @unique_key_drops = []
        end

        def validate_constraint(name)
          @constraint_validations << name
        end

        def add_exclusion_constraint(expression, options)
          @exclusion_constraint_adds << @td.new_exclusion_constraint_definition(expression, options)
        end

        def drop_exclusion_constraint(constraint_name)
          @exclusion_constraint_drops << constraint_name
        end

        def add_unique_key(column_name, options)
          @unique_key_adds << @td.new_unique_key_definition(column_name, options)
        end

        def drop_unique_key(unique_key_name)
          @unique_key_drops << unique_key_name
        end
      end
    end
  end
end
