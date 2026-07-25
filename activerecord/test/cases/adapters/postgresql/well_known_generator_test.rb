# frozen_string_literal: true

require "cases/helper"
require "active_record/connection_adapters/postgresql/oid/well_known_generator"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      class WellKnownGeneratorTest < ActiveRecord::TestCase
        test "build_mappings parses pg_type and pg_range data" do
          generator = OID::WellKnown::Generator.new

          mappings = generator.build_mappings(
            pg_type_source: <<~PG_TYPE,
              [
              { oid => '16', array_type_oid => '1000', typname => 'bool', typinput => 'boolin' },
              { oid => '18', typname => 'char', typinput => 'charin', typcategory => 'Z' },
              { oid => '23', array_type_oid => '1007', typname => 'int4', typinput => 'int4in' },
              { oid => '210', typname => 'smgr', typinput => 'smgrin' },
              { oid => '194', typname => 'pg_node_tree', typinput => 'pg_node_tree_in', typcategory => 'Z' },
              { oid => '83', typname => 'pg_class', typtype => 'c', typinput => 'record_in' },
              { oid => '2249', typname => 'record', typtype => 'p', typinput => 'record_in' },
              { oid => '2277', typname => 'anyarray', typtype => 'p', typinput => 'anyarray_in' },
              { oid => '600', array_type_oid => '1020', typname => 'box', typinput => 'box_in', typdelim => ';' },
              { oid => '1020', typname => '_box', typinput => 'array_in', typelem => 'box', typdelim => ';' },
              { oid => '20000', typname => '_synthetic_not_array', typinput => 'boolin' },
              { oid => '3904', typname => 'int4range', typtype => 'r' },
              { oid => '5000', typname => 'mydomain', typtype => 'd', typbasetype => 'int4' },
              ]
            PG_TYPE
            pg_range_source: <<~PG_RANGE,
              [
              { rngtypid => 'int4range', rngsubtype => 'int4' },
              ]
            PG_RANGE
            pg_version: 11
          )

          assert_equal "bool", mappings[:type_aliases][16]
          assert_equal "char", mappings[:type_aliases][18]
          assert_equal "int4range", mappings[:type_aliases][3904]
          assert_equal "record", mappings[:type_aliases][2249]
          assert_not_includes mappings[:type_aliases].values, "smgr"
          assert_not_includes mappings[:type_aliases].values, "pg_class"
          assert_not_includes mappings[:type_aliases].values, "pg_node_tree"
          assert_not_includes mappings[:type_aliases].values, "anyarray"
          assert_not_includes mappings[:type_aliases].values, "_box"
          assert_equal "_synthetic_not_array", mappings[:type_aliases][20000]
          assert_equal 16, mappings[:array_types][1000]
          assert_equal 600, mappings[:array_types][1020]
          assert_equal ";", mappings[:array_type_delimiters][1020]
          assert_nil mappings[:array_type_delimiters][1000]
          assert_equal 23, mappings[:range_types][3904]
          assert_equal 23, mappings[:domain_types][5000]
        end

        test "render serializes mappings into well_known module constants" do
          generator = OID::WellKnown::Generator.new

          rendered = generator.render(
            mappings_by_version: {
              11 => {
                type_aliases: { 16 => "bool" },
                array_types: { 1000 => 16, 1020 => 16 },
                array_type_delimiters: { 1020 => ";" },
                range_types: { 3904 => 23 },
                domain_types: { 5000 => 23 }
              },
              12 => {
                type_aliases: { 16 => "bool", 24 => "regproc" },
                array_types: { 1000 => 16, 1020 => 16, 1008 => 24 },
                array_type_delimiters: { 1020 => ";" },
                range_types: { 3904 => 23 },
                domain_types: { 5000 => 23 }
              }
            }
          )

          assert_includes rendered, "# This file is generated. Do not edit manually."
          assert_includes rendered, "#   bundle exec rake db:postgresql:update_well_known_oids"
          assert_includes rendered, "FIRST_UNKNOWN_PG_VERSION = 13_00_00"
          assert_includes rendered, "def self.type_aliases_for_version(version)"
          assert_includes rendered, "ARRAY_TYPES = {"
          assert_includes rendered, "ARRAY_TYPE_DELIMITERS = {"
          assert_includes rendered, "RANGE_TYPES = {"
          assert_includes rendered, "DOMAIN_TYPES = {"
          assert_includes rendered, "if version >= 12_00_00"
          assert_includes rendered, "mapping = {\n"
          assert_includes rendered, 'mapping[24] = "regproc"'
          assert_includes rendered, "1008 => 24,"
          assert_includes rendered, "}\n\n            if version >= 12_00_00"
          assert_includes rendered, "            end\n\n            mapping.freeze"
        end

        test "stable_branches_by_version only includes versions with static catalogs" do
          generator = OID::WellKnown::Generator.new
          refs = <<~JSON
            [
              { "ref": "refs/heads/REL9_5_STABLE" },
              { "ref": "refs/heads/REL_10_STABLE" },
              { "ref": "refs/heads/REL_11_STABLE" },
              { "ref": "refs/heads/REL_12_STABLE" }
            ]
          JSON

          generator.stub(:fetch_catalog, refs) do
            assert_equal({ 11 => "REL_11_STABLE", 12 => "REL_12_STABLE" }, generator.send(:stable_branches_by_version))
          end
        end
      end
    end
  end
end
