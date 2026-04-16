# frozen_string_literal: true

require "cases/helper"
require "active_record/connection_adapters/postgresql/oid/well_known"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class WellKnownTest < ActiveRecord::TestCase
        test "uses version 11 mappings for earlier server versions" do
          version_11 = OID::WellKnown.mappings_for(server_version: 11_00_00)
          version_9_5 = OID::WellKnown.mappings_for(server_version: 9_05_00)

          assert_equal version_11.fetch(:type_aliases), version_9_5.fetch(:type_aliases)
          assert_equal version_11.fetch(:array_types), version_9_5.fetch(:array_types)
        end

        test "uses latest known mappings for newer server versions" do
          latest = OID::WellKnown.mappings_for(server_version: OID::WellKnown::FIRST_UNKNOWN_PG_VERSION - 1_00_00)
          future = OID::WellKnown.mappings_for(server_version: 99_00_00)

          assert_equal latest.fetch(:type_aliases), future.fetch(:type_aliases)
          assert_equal latest.fetch(:array_types), future.fetch(:array_types)
        end

        test "filters pseudo type aliases except record" do
          mappings = OID::WellKnown.mappings_for(server_version: 14_00_00)
          type_oids = mappings.fetch(:type_oids)

          assert_equal 2249, type_oids.fetch("record")
          assert_equal 18, type_oids.fetch("char")
          assert_not type_oids.key?("pg_class")
          assert_not type_oids.key?("pg_node_tree")
          assert_not type_oids.key?("pg_snapshot")
          assert_not type_oids.key?("smgr")
          assert_not type_oids.key?("anyarray")
          assert_not type_oids.key?("opaque")
        end

        test "shares static secondary mappings across versions" do
          version_11 = OID::WellKnown.mappings_for(server_version: 11_00_00)
          version_18 = OID::WellKnown.mappings_for(server_version: 18_00_00)

          assert_same version_11.fetch(:array_types), version_18.fetch(:array_types)
          assert_same version_11.fetch(:array_type_delimiters), version_18.fetch(:array_type_delimiters)
          assert_same version_11.fetch(:range_types), version_18.fetch(:range_types)
          assert_same version_11.fetch(:domain_types), version_18.fetch(:domain_types)
        end
      end
    end
  end
end
