# frozen_string_literal: true

module ActiveRecord
  module ConnectionAdapters
    module MySQL
      module ColumnMethods
        def blob(*args, **options)
          args.each { |name| column(name, :blob, options) }
        end

        def tinyblob(*args, **options)
          args.each { |name| column(name, :tinyblob, options) }
        end

        def mediumblob(*args, **options)
          args.each { |name| column(name, :mediumblob, options) }
        end

        def longblob(*args, **options)
          args.each { |name| column(name, :longblob, options) }
        end

        def tinytext(*args, **options)
          args.each { |name| column(name, :tinytext, options) }
        end

        def mediumtext(*args, **options)
          args.each { |name| column(name, :mediumtext, options) }
        end

        def longtext(*args, **options)
          args.each { |name| column(name, :longtext, options) }
        end

        def unsigned_integer(*args, **options)
          args.each { |name| column(name, :unsigned_integer, options) }
        end

        def unsigned_bigint(*args, **options)
          args.each { |name| column(name, :unsigned_bigint, options) }
        end

        def unsigned_float(*args, **options)
          args.each { |name| column(name, :unsigned_float, options) }
        end

        def unsigned_decimal(*args, **options)
          args.each { |name| column(name, :unsigned_decimal, options) }
        end
      end

      class TableDefinition < ActiveRecord::ConnectionAdapters::TableDefinition
        include ColumnMethods

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
          def aliased_types(_name, fallback)
            fallback
          end

          def integer_like_primary_key_type(type, options)
            options[:auto_increment] = true
            type
          end
      end

      class Table < ActiveRecord::ConnectionAdapters::Table
        include ColumnMethods
      end
    end
  end
end
