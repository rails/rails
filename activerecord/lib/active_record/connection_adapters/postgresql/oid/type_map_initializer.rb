# frozen_string_literal: true

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
            @pending = Hash.new { |h, oid| h[oid] = [] }
            @newly_registered = []
          end

          def pending_oids
            @pending.keys
          end

          def run(records)
            until records.empty?
              records.each do |row|
                next if @store.key?(row["oid"].to_i)

                if @store.key?(row["typname"])
                  alias_type row["oid"].to_i, row["typname"]
                  next
                end

                case row["typtype"]
                when "r"
                  register_or_requeue(row["oid"].to_i, row["rngsubtype"].to_i, row) do |subtype|
                    OID::Range.new(subtype, row["typname"].to_sym)
                  end
                when "e"
                  register row["oid"].to_i, OID::Enum.new
                when "d"
                  register_or_requeue(row["oid"].to_i, row["typbasetype"].to_i, row) do |subtype|
                    subtype
                  end
                else
                  if row["typelem"].to_i != 0
                    register_or_requeue(row["oid"].to_i, row["typelem"].to_i, row) do |subtype|
                      if row["typinput"] == "array_in"
                        OID::Array.new(subtype, row["typdelim"].freeze)
                      else
                        OID::Vector.new(row["typdelim"], subtype)
                      end
                    end
                  end
                end
              end

              previously_registered, @newly_registered = @newly_registered, []
              records = previously_registered.filter_map { |oid| @pending.delete(oid) }.flatten(1)
            end
          end

          private
            def register(oid, oid_type = nil, &block)
              if block_given?
                @store.register_type(oid, &block)
              else
                @store.register_type(oid, oid_type)
              end
              @newly_registered << oid
            end

            def alias_type(oid, target)
              @store.alias_type(oid, target)
              @newly_registered << oid
            end

            def register_or_requeue(oid, target_oid, row)
              if @store.key?(target_oid)
                register(oid) do |_, *args|
                  yield @store.lookup(target_oid, *args)
                end
              else
                @pending[target_oid] << row
              end
            end
        end
      end
    end
  end
end
