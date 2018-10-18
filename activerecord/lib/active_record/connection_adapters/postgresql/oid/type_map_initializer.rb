# frozen_string_literal: true

require "active_support/core_ext/array/extract"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID # :nodoc:
        # This class uses the data from PostgreSQL pg_type table to build
        # the OID -> Type mapping.
        #   - OID is an integer representing the type.
        #   - Type is an OID::Type object.
        # This class has side effects on the +store+ passed during initialization.
        class TypeMapInitializer # :nodoc:
          def initialize(store)
            @store = store
          end

          def run(records)
            nodes = records.reject { |row| @store.key? row["oid"].to_i }
            mapped = nodes.extract! { |row| @store.key? row["typname"] }
            ranges = nodes.extract! { |row| row["typtype"] == "r" }
            enums = nodes.extract! { |row| row["typtype"] == "e" }
            domains = nodes.extract! { |row| row["typtype"] == "d" }
            arrays = nodes.extract! { |row| row["typinput"] == "array_in" }
            composites = nodes.extract! { |row| row["typelem"].to_i != 0 }

            mapped.each     { |row| register_mapped_type(row)    }
            enums.each      { |row| register_enum_type(row)      }
            domains.each    { |row| register_domain_type(row)    }
            arrays.each     { |row| register_array_type(row)     }
            ranges.each     { |row| register_range_type(row)     }
            composites.each { |row| register_composite_type(row) }
          end

          def query_conditions_for_initial_load
            known_type_names = @store.keys.map { |n| "'#{n}'" }
            known_type_types = %w('r' 'e' 'd')
            <<-SQL % [known_type_names.join(", "), known_type_types.join(", ")]
              WHERE
                t.typname IN (%s)
                OR t.typtype IN (%s)
                OR t.typinput = 'array_in(cstring,oid,integer)'::regprocedure
                OR t.typelem != 0
            SQL
          end

          private
            def register_mapped_type(row)
              alias_type row["oid"], row["typname"]
            end

            def register_enum_type(row)
              register row["oid"], OID::Enum.new
            end

            def register_array_type(row)
              register_with_subtype(row["oid"], row["typelem"].to_i) do |subtype|
                OID::Array.new(subtype, row["typdelim"])
              end
            end

            def register_range_type(row)
              register_with_subtype(row["oid"], row["rngsubtype"].to_i) do |subtype|
                OID::Range.new(subtype, row["typname"].to_sym)
              end
            end

            def register_domain_type(row)
              if base_type = @store.lookup(row["typbasetype"].to_i)
                register row["oid"], base_type
              else
                warn "unknown base type (OID: #{row["typbasetype"]}) for domain #{row["typname"]}."
              end
            end

            def register_composite_type(row)
              if subtype = @store.lookup(row["typelem"].to_i)
                register row["oid"], OID::Vector.new(row["typdelim"], subtype)
              end
            end

            def register(oid, oid_type = nil, &block)
              oid = assert_valid_registration(oid, oid_type || block)
              if block_given?
                @store.register_type(oid, &block)
              else
                @store.register_type(oid, oid_type)
              end
            end

            def alias_type(oid, target)
              oid = assert_valid_registration(oid, target)
              @store.alias_type(oid, target)
            end

            def register_with_subtype(oid, target_oid)
              if @store.key?(target_oid)
                register(oid) do |_, *args|
                  yield @store.lookup(target_oid, *args)
                end
              end
            end

            def assert_valid_registration(oid, oid_type)
              raise ArgumentError, "can't register nil type for OID #{oid}" if oid_type.nil?
              oid.to_i
            end
        end
      end
    end
  end
end
