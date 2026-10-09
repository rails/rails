# frozen_string_literal: true

require "zlib"

module ARTest
  module DatabaseSlot
    MAX = 5

    class << self
      def claim!
        config = ARTest.test_configuration_hashes
        return if config["arunit"]["database"] == ":memory:"

        base_configs = config.values_at("arunit", "arunit2")
        ARTest.slot =
          if base_configs.first["adapter"] == "sqlite3"
            claim_file(base_configs)
          else
            claim_server(base_configs)
          end
      end

      private
        def claim_file(base_configs)
          first_free_slot do |slot|
            file = File.open("#{slot_configs(base_configs, slot).first["database"]}.lock", File::RDWR | File::CREAT)
            if file.flock(File::LOCK_EX | File::LOCK_NB)
              @holder = file
            else
              file.close
              false
            end
          end
        end

        def claim_server(base_configs)
          home = base_configs.first
          adapter = new_adapter(home)
          return 0 unless adapter.supports_advisory_locks?

          create_database(home) unless database_exists?(home)
          adapter.connect!

          slot = first_free_slot do |slot|
            adapter.get_advisory_lock(Zlib.crc32(slot_configs(base_configs, slot).first["database"]))
          end

          slot_configs(base_configs, slot).each do |db_config|
            create_database(db_config) unless database_exists?(db_config)
          end

          # A forked child closing this connection would release our lock
          ActiveSupport::ForkTracker.after_fork { adapter.discard! }
          @holder = adapter

          slot
        end

        def first_free_slot(&block)
          (0...MAX).find(&block) or raise "All #{MAX} database slots are in use"
        end

        def slot_configs(base_configs, slot)
          base_configs.map do |db_config|
            db_config.merge("database" => ARTest.slotted_name(db_config["database"], slot))
          end
        end

        def new_adapter(db_config)
          ActiveRecord::ConnectionAdapters.resolve(db_config["adapter"]).new(db_config)
        end

        def database_exists?(db_config)
          with_adapter(db_config, &:database_exists?)
        end

        # Matching the Rakefile's options where we know them
        def create_database(db_config)
          case db_config["adapter"]
          when "postgresql"
            maintenance = db_config.merge("database" => db_config.fetch("maintenance_database", "postgres"))
            with_adapter(maintenance) { |a| a.create_database(db_config["database"], template: "template0", collation: "en_US.UTF-8") }
          when "mysql2", "trilogy"
            with_adapter(db_config.merge("database" => nil)) { |a| a.create_database(db_config["database"], charset: "utf8mb4") }
          else
            ActiveRecord::Tasks::DatabaseTasks.create(db_config)
          end
        rescue ActiveRecord::DatabaseAlreadyExists, ActiveRecord::RecordNotUnique
          # Concurrently created; PostgreSQL may report a unique violation
        end

        def with_adapter(db_config)
          adapter = new_adapter(db_config)
          begin
            yield adapter
          ensure
            adapter.disconnect!
          end
        end
    end
  end
end
