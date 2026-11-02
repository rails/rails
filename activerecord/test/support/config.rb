# frozen_string_literal: true

require "fileutils"
require "pathname"
require "active_support/configuration_file"
require "active_support/core_ext/file/atomic"

module ARTest
  class << self
    def config
      @config ||= read_config
    end

    def slot
      @slot || 0
    end

    def slot=(slot)
      @slot = slot
      @config = nil
    end

    # "name.N.ext" for files, "name_N" for databases
    def slotted_name(name, slot = self.slot)
      return name if slot == 0 || name == ":memory:"

      ext = File.extname(name)
      if ext.empty?
        "#{name}_#{slot}"
      else
        "#{name.delete_suffix(ext)}.#{slot}#{ext}"
      end
    end

    private
      def config_file
        Pathname.new(ENV["ARCONFIG"] || TEST_ROOT + "/config.yml")
      end

      def read_config
        unless config_file.exist?
          File.atomic_write(config_file) { |f| f.write File.read(TEST_ROOT + "/config.example.yml") }
        end

        expand_config ActiveSupport::ConfigurationFile.parse(config_file)
      end

      def expand_config(config)
        config["connections"].each do |adapter, connection|
          dbs = [["arunit", "activerecord_unittest"], ["arunit2", "activerecord_unittest2"],
                 ["arunit_without_prepared_statements", "activerecord_unittest"]]
          dbs.each do |name, dbname|
            unless connection[name].is_a?(Hash)
              connection[name] = { "database" => connection[name] }
            end

            connection[name]["database"] ||= dbname
            connection[name]["database"] = slotted_name(connection[name]["database"])
            connection[name]["adapter"]  ||= adapter.start_with?("sqlite3") ? "sqlite3" : adapter
          end
        end

        config
      end
  end
end
