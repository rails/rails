# frozen_string_literal: true

require "active_record/connection_adapters/postgresql/oid/well_known_values"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        module WellKnown # :nodoc:
          @mappings_cache = Concurrent::Map.new

          class << self
            def register_types(store, server_version:)
              mappings = mappings_for(server_version: server_version)
              register_type_aliases(store, mappings.fetch(:type_aliases))
              register_domain_types(store, mappings.fetch(:domain_types))
              register_array_types(
                store,
                mappings.fetch(:array_types),
                mappings.fetch(:array_type_delimiters)
              )
              register_range_types(store, mappings.fetch(:range_types), mappings.fetch(:type_aliases))
            end

            def type_oids_for(server_version:)
              mappings_for(server_version: server_version).fetch(:type_oids)
            end

            def mappings_for(server_version:)
              @mappings_cache.fetch_or_store(server_version) { build_mappings_for(server_version) }
            end

            private
              def build_mappings_for(version)
                type_aliases = type_aliases_for_version(version)
                {
                  type_aliases: type_aliases,
                  array_types: ARRAY_TYPES,
                  array_type_delimiters: ARRAY_TYPE_DELIMITERS,
                  range_types: RANGE_TYPES,
                  domain_types: DOMAIN_TYPES,
                  type_oids: type_aliases.invert.freeze
                }.freeze
              end

              def register_type_aliases(store, type_aliases)
                type_aliases.each do |oid, type_name|
                  next unless store.key?(type_name)

                  store.alias_type(oid, type_name)
                end
              end

              def register_domain_types(store, domain_types)
                domain_types.each do |oid, base_oid|
                  next unless store.key?(base_oid)

                  store.register_type(oid, store.lookup(base_oid))
                end
              end

              def register_array_types(store, array_types, delimiters)
                array_types.each do |oid, subtype_oid|
                  next unless store.key?(subtype_oid)

                  delimiter = delimiters.fetch(oid, ",")
                  store.register_type(oid) do |_, *args|
                    OID::Array.new(store.lookup(subtype_oid, *args), delimiter)
                  end
                end
              end

              def register_range_types(store, range_types, type_aliases)
                range_types.each do |oid, subtype_oid|
                  next unless store.key?(subtype_oid)

                  range_name = type_aliases[oid]&.to_sym
                  next unless range_name

                  store.register_type(oid) do |_, *args|
                    OID::Range.new(store.lookup(subtype_oid, *args), range_name)
                  end
                end
              end
          end
        end
      end
    end
  end
end
