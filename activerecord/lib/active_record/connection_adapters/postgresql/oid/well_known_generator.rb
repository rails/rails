# frozen_string_literal: true

require "digest/sha2"
require "fileutils"
require "json"
require "net/http"

require "active_support/core_ext/string/indent"

module ActiveRecord
  module ConnectionAdapters
    module PostgreSQL
      module OID
        module WellKnown # :nodoc:
          class Generator # :nodoc:
            PG_GIT_REF_API_URL = "https://api.github.com/repos/postgres/postgres/git/matching-refs/heads/REL"
            PG_RAW_BASE_URL = "https://raw.githubusercontent.com/postgres/postgres/refs/heads"
            PG_TYPE_CATALOG_PATH = "src/include/catalog/pg_type.dat"
            PG_RANGE_CATALOG_PATH = "src/include/catalog/pg_range.dat"
            MINIMUM_STATIC_VERSION = 11
            OUTPUT_PATH = File.expand_path("well_known_values.rb", __dir__)
            CACHE_PATH = File.expand_path("../../../../../../tmp/postgresql_oid_catalog_cache", __dir__)
            EXCLUDED_TYPE_OIDS = [
              # Deprecated/legacy built-ins removed in newer PostgreSQL versions.
              210, 702, 703, 704, # smgr, abstime, reltime, tinterval
            ].freeze

            class << self
              def generate!(...)
                new(...).generate!
              end
            end

            def initialize(
              output_path: OUTPUT_PATH,
              cache_path: CACHE_PATH,
              pg_type_source: nil,
              pg_range_source: nil,
              pg_version: nil
            )
              @output_path = output_path
              @cache_path = cache_path
              @pg_type_source = pg_type_source
              @pg_range_source = pg_range_source
              @pg_version = pg_version
            end

            def generate!
              validate_input_pairs!

              mappings_by_version = resolve_catalogs_by_version.each_with_object({}) do |(version, catalogs), mappings|
                mappings[version] = build_mappings(
                  pg_type_source: catalogs.fetch(:pg_type_source),
                  pg_range_source: catalogs.fetch(:pg_range_source),
                  pg_version: version
                )
              end

              output = render(mappings_by_version: mappings_by_version)
              File.write(@output_path, output)

              {
                mappings_by_version: mappings_by_version
              }
            end

            def build_mappings(pg_type_source:, pg_range_source:, pg_version:)
              type_rows = parse_catalog_rows(pg_type_source).select { |row| row["oid"] && row["typname"] }
              type_rows.sort_by! { |row| row["oid"].to_i }

              name_to_oid = type_rows.to_h { |row| [row["typname"], row["oid"].to_i] }
              array_types, array_type_delimiters = build_array_types(type_rows, name_to_oid)

              {
                type_aliases: build_type_aliases(type_rows, pg_version: pg_version),
                array_types: array_types,
                array_type_delimiters: array_type_delimiters,
                range_types: build_range_types(parse_catalog_rows(pg_range_source), name_to_oid),
                domain_types: build_domain_types(type_rows, name_to_oid)
              }
            end

            def render(mappings_by_version:)
              versions = mappings_by_version.keys.sort
              type_aliases_base, type_aliases_additions, type_aliases_removals = build_delta_series(mappings_by_version, :type_aliases)

              type_aliases_method = render_versioned_builder_method(
                method_name: "type_aliases_for_version",
                base: type_aliases_base,
                additions: type_aliases_additions,
                removals: type_aliases_removals
              )
              array_types_constant = render_hash_constant("ARRAY_TYPES", build_static_union(mappings_by_version, :array_types))
              array_type_delimiters_constant = render_hash_constant("ARRAY_TYPE_DELIMITERS", build_static_union(mappings_by_version, :array_type_delimiters))
              range_types_constant = render_hash_constant("RANGE_TYPES", build_static_union(mappings_by_version, :range_types))
              domain_types_constant = render_hash_constant("DOMAIN_TYPES", build_static_union(mappings_by_version, :domain_types))

              <<~RUBY
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
                          FIRST_UNKNOWN_PG_VERSION = #{format_pg_version(versions.max + 1)}

                          #{type_aliases_method.indent(10).strip}

                          #{array_types_constant.indent(10).strip}

                          #{array_type_delimiters_constant.indent(10).strip}

                          #{range_types_constant.indent(10).strip}

                          #{domain_types_constant.indent(10).strip}
                        end
                      end
                    end
                  end
                end
              RUBY
            end

            private
              def validate_input_pairs!
                if @pg_type_source.nil? ^ @pg_range_source.nil?
                  raise ArgumentError, "pass both pg_type_source and pg_range_source or neither"
                end

                if (@pg_type_source || @pg_range_source) && !@pg_version
                  raise ArgumentError, "pass pg_version when using pg_type_source and pg_range_source"
                end

                if @pg_version && !(@pg_type_source && @pg_range_source)
                  raise ArgumentError, "pg_version override requires both pg_type_source and pg_range_source"
                end
              end

              def resolve_catalogs_by_version
                if @pg_type_source && @pg_range_source
                  return {
                    @pg_version => {
                      pg_type_source: @pg_type_source,
                      pg_range_source: @pg_range_source
                    }
                  }
                end

                stable_branches_by_version.each_with_object({}) do |(version, branch_name), catalogs|
                  pg_type_url = catalog_url(branch_name, PG_TYPE_CATALOG_PATH)
                  pg_range_url = catalog_url(branch_name, PG_RANGE_CATALOG_PATH)

                  catalogs[version] = {
                    pg_type_source: fetch_catalog(pg_type_url, cache: true),
                    pg_range_source: fetch_catalog(pg_range_url, cache: true)
                  }
                end
              end

              def stable_branches_by_version
                refs = stable_refs
                latest_version = refs.map { |ref| ref.fetch(:version) }.max
                raise "could not find a PostgreSQL REL_*_STABLE branch" unless latest_version

                refs_by_version = refs.group_by { |ref| ref.fetch(:version) }
                selected = {}

                MINIMUM_STATIC_VERSION.upto(latest_version) do |version|
                  ref = refs_by_version[version]&.max_by { |entry| entry.fetch(:minor_version) }
                  next unless ref

                  selected[version] = ref.fetch(:branch_name)
                end

                raise "could not find PostgreSQL REL_#{MINIMUM_STATIC_VERSION}_STABLE branch" if selected.empty?

                selected
              end

              def stable_refs
                refs = JSON.parse(fetch_catalog(PG_GIT_REF_API_URL, cache: false))
                refs.filter_map do |entry|
                  parse_stable_ref(entry["ref"])
                end
              end

              def parse_stable_ref(ref)
                branch_name = ref.to_s.split("/").last

                if branch_name =~ /\AREL_(\d+)_STABLE\z/
                  {
                    branch_name: branch_name,
                    version: Regexp.last_match(1).to_i,
                    minor_version: 0
                  }
                elsif branch_name =~ /\AREL(\d+)_(\d+)_STABLE\z/
                  {
                    branch_name: branch_name,
                    version: Regexp.last_match(1).to_i,
                    minor_version: Regexp.last_match(2).to_i
                  }
                end
              end

              def catalog_url(branch_name, catalog_path)
                "#{PG_RAW_BASE_URL}/#{branch_name}/#{catalog_path}"
              end

              def fetch_catalog(url, redirect_limit: 5, cache: true)
                raise ArgumentError, "too many redirects while fetching #{url}" if redirect_limit <= 0

                if cache
                  cached = read_cached_catalog(url)
                  return cached if cached
                end

                uri = URI.parse(url)
                raise ArgumentError, "catalog URL must use HTTPS: #{url}" unless uri.is_a?(URI::HTTPS)

                response = Net::HTTP.get_response(uri)

                case response
                when Net::HTTPSuccess
                  body = response.body
                  write_cached_catalog(url, body) if cache
                  body
                when Net::HTTPRedirection
                  location = response["location"]
                  raise "redirect response missing location while fetching #{url}" unless location

                  resolved_url = URI.join(url, location).to_s
                  body = fetch_catalog(resolved_url, redirect_limit: redirect_limit - 1, cache: cache)
                  write_cached_catalog(url, body) if cache
                  body
                else
                  response.value
                end
              end

              def read_cached_catalog(url)
                cache_file_path = cache_file_path_for(url)
                return unless File.exist?(cache_file_path)

                File.read(cache_file_path)
              end

              def write_cached_catalog(url, body)
                FileUtils.mkdir_p(@cache_path)
                File.write(cache_file_path_for(url), body)
              end

              def cache_file_path_for(url)
                uri = URI.parse(url)
                digest = Digest::SHA256.hexdigest(url)[0, 12]
                slug = [uri.host, uri.path, uri.query].compact.join("__").gsub(/[^A-Za-z0-9._-]+/, "_")
                File.join(@cache_path, "#{slug}-#{digest}")
              end

              def parse_catalog_rows(source)
                source.scan(/\{(.*?)\},/m).map { |record| parse_catalog_row(record.first) }
              end

              def parse_catalog_row(record)
                record.scan(/([a-z_]+)\s*=>\s*'((?:\\'|[^'])*)'/m).to_h.transform_values do |value|
                  value.gsub("\\'", "'")
                end
              end

              def build_array_types(type_rows, name_to_oid)
                array_types = {}
                array_type_delimiters = {}

                type_rows.each do |row|
                  next unless row["array_type_oid"]

                  add_array_type(array_types, array_type_delimiters, row["array_type_oid"].to_i, row["oid"].to_i, row.fetch("typdelim", ","))
                end

                type_rows.each do |row|
                  next unless row["typinput"] == "array_in"

                  subtype_oid = resolve_oid_reference(row["typelem"], name_to_oid)
                  next unless subtype_oid

                  add_array_type(array_types, array_type_delimiters, row["oid"].to_i, subtype_oid, row.fetch("typdelim", ","))
                end

                [array_types, array_type_delimiters]
              end

              def build_type_aliases(type_rows, pg_version:)
                type_rows.each_with_object({}) do |row, type_aliases|
                  next if row["typtype"] == "p" && row["typname"] != "record"
                  next if row["typtype"] == "c"
                  next if row["typcategory"] == "Z" && row["typname"] != "char"
                  next if EXCLUDED_TYPE_OIDS.include?(row["oid"].to_i)
                  next if row["typname"].start_with?("pg_")

                  if pg_version < 12
                    # Pre-12 catalogs include many named array aliases.
                    # Identify them by catalog attributes instead of typname alone.
                    next if row["typname"].start_with?("_") && row["typinput"] == "array_in" && row["typelem"].to_s != ""
                  end

                  type_aliases[row["oid"].to_i] = row["typname"]
                end
              end

              def add_array_type(array_types, array_type_delimiters, array_oid, subtype_oid, delimiter)
                array_types[array_oid] = subtype_oid
                array_type_delimiters[array_oid] = delimiter if delimiter != ","
              end

              def build_range_types(range_rows, name_to_oid)
                range_rows.each_with_object({}) do |row, range_types|
                  range_oid = resolve_oid_reference(row["rngtypid"], name_to_oid)
                  subtype_oid = resolve_oid_reference(row["rngsubtype"], name_to_oid)
                  next unless range_oid && subtype_oid

                  range_types[range_oid] = subtype_oid
                end
              end

              def build_domain_types(type_rows, name_to_oid)
                type_rows.each_with_object({}) do |row, domain_types|
                  next unless row["typtype"] == "d"

                  base_oid = resolve_oid_reference(row["typbasetype"], name_to_oid)
                  next unless base_oid

                  domain_types[row["oid"].to_i] = base_oid
                end
              end

              def resolve_oid_reference(value, name_to_oid)
                return if value.nil? || value.empty?
                return value.to_i if value.match?(/\A\d+\z/)

                name_to_oid[value]
              end

              def build_delta_series(mappings_by_version, key)
                versions = mappings_by_version.keys.sort
                previous_mapping = mappings_by_version.fetch(versions.first).fetch(key)
                base_mapping = previous_mapping
                additions = {}
                removals = {}

                versions.drop(1).each do |version|
                  mapping = mappings_by_version.fetch(version).fetch(key)
                  added_or_changed = mapping.each_with_object({}) do |(oid, value), memo|
                    memo[oid] = value if previous_mapping[oid] != value
                  end
                  removed = (previous_mapping.keys - mapping.keys).sort

                  additions[version] = added_or_changed unless added_or_changed.empty?
                  removals[version] = removed unless removed.empty?
                  previous_mapping = mapping
                end

                [base_mapping, additions, removals]
              end

              def render_versioned_builder_method(method_name:, base:, additions:, removals:)
                steps = render_versioned_builder_steps(additions: additions, removals: removals)
                steps = steps.empty? ? "" : "\n\n#{steps.indent(2).rstrip}\n"
                base_mapping = render_hash(base).indent(2).sub(/\A +/, "").rstrip

                <<~RUBY
                  def self.#{method_name}(version)
                    mapping = #{base_mapping}#{steps}
                    mapping.freeze
                  end
                RUBY
              end

              def render_versioned_builder_steps(additions:, removals:)
                versions = (additions.keys + removals.keys).uniq.sort
                return "" if versions.empty?

                versions.map do |version|
                  added_or_changed = additions.fetch(version, {})
                  removed = removals.fetch(version, [])

                  [
                    "if version >= #{format_pg_version(version)}",
                    *removed.sort.map { |oid| "  mapping.delete(#{oid.inspect})" },
                    *added_or_changed.sort.map { |oid, value| "  mapping[#{oid.inspect}] = #{value.inspect}" },
                    "end"
                  ].join("\n")
                end.join("\n\n")
              end

              def format_pg_version(version)
                "#{version}_00_00"
              end

              def render_hash(hash)
                if hash.empty?
                  "{}"
                else
                  "{\n" +
                    hash.sort.map do |key, value|
                      "  #{key.inspect} => #{value.inspect},\n"
                    end.join +
                    "}"
                end
              end

              def render_hash_constant(constant_name, hash)
                <<~RUBY
                  #{constant_name} = #{render_hash(hash)}.freeze
                RUBY
              end

              def build_static_union(mappings_by_version, key)
                mappings_by_version.keys.sort.each_with_object({}) do |version, union|
                  mappings_by_version.fetch(version).fetch(key).each do |oid, value|
                    if union.key?(oid) && union[oid] != value
                      raise "#{key} has conflicting values for OID #{oid}: #{union[oid].inspect} vs #{value.inspect} in PostgreSQL #{version}"
                    end

                    union[oid] = value
                  end
                end
              end
          end
        end
      end
    end
  end
end
