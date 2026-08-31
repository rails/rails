# frozen_string_literal: true

# This file is generated. Do not edit manually.
#
# To regenerate:
#   bundle exec rake db:postgresql:update_well_known_oids

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        module WellKnown # :nodoc:
          FIRST_UNKNOWN_PG_VERSION = 19_00_00

          def self.type_aliases_for_version(version)
            mapping = {
              16 => "bool",
              17 => "bytea",
              18 => "char",
              19 => "name",
              20 => "int8",
              21 => "int2",
              22 => "int2vector",
              23 => "int4",
              24 => "regproc",
              25 => "text",
              26 => "oid",
              27 => "tid",
              28 => "xid",
              29 => "cid",
              30 => "oidvector",
              114 => "json",
              142 => "xml",
              600 => "point",
              601 => "lseg",
              602 => "path",
              603 => "box",
              604 => "polygon",
              628 => "line",
              650 => "cidr",
              700 => "float4",
              701 => "float8",
              718 => "circle",
              774 => "macaddr8",
              790 => "money",
              829 => "macaddr",
              869 => "inet",
              1033 => "aclitem",
              1042 => "bpchar",
              1043 => "varchar",
              1082 => "date",
              1083 => "time",
              1114 => "timestamp",
              1184 => "timestamptz",
              1186 => "interval",
              1266 => "timetz",
              1560 => "bit",
              1562 => "varbit",
              1700 => "numeric",
              1790 => "refcursor",
              2202 => "regprocedure",
              2203 => "regoper",
              2204 => "regoperator",
              2205 => "regclass",
              2206 => "regtype",
              2249 => "record",
              2950 => "uuid",
              2970 => "txid_snapshot",
              3614 => "tsvector",
              3615 => "tsquery",
              3642 => "gtsvector",
              3734 => "regconfig",
              3769 => "regdictionary",
              3802 => "jsonb",
              3904 => "int4range",
              3906 => "numrange",
              3908 => "tsrange",
              3910 => "tstzrange",
              3912 => "daterange",
              3926 => "int8range",
              4089 => "regnamespace",
              4096 => "regrole",
            }

            if version >= 12_00_00
              mapping[4072] = "jsonpath"
            end

            if version >= 13_00_00
              mapping[4191] = "regcollation"
              mapping[5069] = "xid8"
            end

            if version >= 14_00_00
              mapping[4451] = "int4multirange"
              mapping[4532] = "nummultirange"
              mapping[4533] = "tsmultirange"
              mapping[4534] = "tstzmultirange"
              mapping[4535] = "datemultirange"
              mapping[4536] = "int8multirange"
            end

            mapping.freeze
          end

          ARRAY_TYPES = {
            143 => 142,
            199 => 114,
            210 => 71,
            270 => 75,
            271 => 5069,
            272 => 81,
            273 => 83,
            629 => 628,
            651 => 650,
            719 => 718,
            775 => 774,
            791 => 790,
            1000 => 16,
            1001 => 17,
            1002 => 18,
            1003 => 19,
            1005 => 21,
            1006 => 22,
            1007 => 23,
            1008 => 24,
            1009 => 25,
            1010 => 27,
            1011 => 28,
            1012 => 29,
            1013 => 30,
            1014 => 1042,
            1015 => 1043,
            1016 => 20,
            1017 => 600,
            1018 => 601,
            1019 => 602,
            1020 => 603,
            1021 => 700,
            1022 => 701,
            1023 => 702,
            1024 => 703,
            1025 => 704,
            1027 => 604,
            1028 => 26,
            1034 => 1033,
            1040 => 829,
            1041 => 869,
            1115 => 1114,
            1182 => 1082,
            1183 => 1083,
            1185 => 1184,
            1187 => 1186,
            1231 => 1700,
            1263 => 2275,
            1270 => 1266,
            1561 => 1560,
            1563 => 1562,
            2201 => 1790,
            2207 => 2202,
            2208 => 2203,
            2209 => 2204,
            2210 => 2205,
            2211 => 2206,
            2287 => 2249,
            2949 => 2970,
            2951 => 2950,
            3221 => 3220,
            3643 => 3614,
            3644 => 3642,
            3645 => 3615,
            3735 => 3734,
            3770 => 3769,
            3807 => 3802,
            3905 => 3904,
            3907 => 3906,
            3909 => 3908,
            3911 => 3910,
            3913 => 3912,
            3927 => 3926,
            4073 => 4072,
            4090 => 4089,
            4097 => 4096,
            4192 => 4191,
            5039 => 5038,
            6150 => 4451,
            6151 => 4532,
            6152 => 4533,
            6153 => 4534,
            6155 => 4535,
            6157 => 4536,
          }.freeze

          ARRAY_TYPE_DELIMITERS = {
            1020 => ";",
          }.freeze

          RANGE_TYPES = {
            3904 => 23,
            3906 => 1700,
            3908 => 1114,
            3910 => 1184,
            3912 => 1082,
            3926 => 20,
          }.freeze

          DOMAIN_TYPES = {}.freeze
        end
      end
    end
  end
end
