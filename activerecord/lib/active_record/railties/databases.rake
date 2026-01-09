# frozen_string_literal: true

require "active_record"
require "active_support/configuration_file"
require "active_support/deprecation"

databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml

db_namespace = namespace :db do
  desc "Set the environment value for the database"
  task "environment:set" => :load_config do
    pool = ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool
    raise ActiveRecord::EnvironmentStorageError unless pool.internal_metadata.enabled?

    pool.internal_metadata.create_table_and_set_flags(pool.migration_context.current_environment)
  end

  task check_protected_environments: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.check_protected_environments!
  end

  task load_config: :environment do
    if ActiveRecord::Base.configurations.empty?
      ActiveRecord::Base.configurations = ActiveRecord::Tasks::DatabaseTasks.database_configuration
    end

    ActiveRecord::Migrator.migrations_paths = ActiveRecord::Tasks::DatabaseTasks.migrations_paths
  end

  namespace :create do
    task all: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.create_all
    end

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Create #{name} database for current environment"
      task name => :load_config do
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
        ActiveRecord::Tasks::DatabaseTasks.create(db_config)
      end
    end
  end

  desc "Create the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:create:all to create all databases in the config). Without RAILS_ENV or when RAILS_ENV is development, it defaults to creating the development and test databases, except when DATABASE_URL is present."
  task create: [:load_config] do
    ActiveRecord::Tasks::DatabaseTasks.create_current
  end

  namespace :drop do
    task all: [:load_config, :check_protected_environments] do
      ActiveRecord::Tasks::DatabaseTasks.drop_all
    end

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Drop #{name} database for current environment"
      task name => [:load_config, :check_protected_environments] do
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
        ActiveRecord::Tasks::DatabaseTasks.drop(db_config)
      end
    end
  end

  desc "Drop the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:drop:all to drop all databases in the config). Without RAILS_ENV or when RAILS_ENV is development, it defaults to dropping the development and test databases, except when DATABASE_URL is present."
  task drop: [:load_config, :check_protected_environments] do
    db_namespace["drop:_unsafe"].invoke
  end

  task "drop:_unsafe" => [:load_config] do
    ActiveRecord::Tasks::DatabaseTasks.drop_current
  end

  namespace :purge do
    task all: [:load_config, :check_protected_environments] do
      ActiveRecord::Tasks::DatabaseTasks.purge_all
    end
  end

  # desc "Truncates tables of each database for current environment"
  task truncate_all: [:load_config, :check_protected_environments] do
    ActiveRecord::Tasks::DatabaseTasks.truncate_all
  end

  # desc "Empty the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:purge:all to purge all databases in the config). Without RAILS_ENV it defaults to purging the development and test databases, except when DATABASE_URL is present."
  task purge: [:load_config, :check_protected_environments] do
    ActiveRecord::Tasks::DatabaseTasks.purge_current
  end

  desc "Migrate the database (options: VERSION=x, VERBOSE=false, SCOPE=blog)."
  task migrate: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.migrate_all
    db_namespace["_dump"].invoke
  end

  # IMPORTANT: This task won't dump the schema if ActiveRecord.dump_schema_after_migration is set to false
  task :_dump do
    if ActiveRecord.dump_schema_after_migration
      db_namespace["schema:dump"].invoke
    end
    # Allow this task to be called as many times as required. An example is the
    # migrate:redo task, which calls other two internally that depend on this one.
    db_namespace["_dump"].reenable
  end

  namespace :_dump do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      # IMPORTANT: This task won't dump the schema if ActiveRecord.dump_schema_after_migration is set to false
      task name do
        if ActiveRecord.dump_schema_after_migration
          db_namespace["schema:dump:#{name}"].invoke
        end

        # Allow this task to be called as many times as required. An example is the
        # migrate:redo task, which calls other two internally that depend on this one.
        db_namespace["_dump:#{name}"].reenable
      end
    end
  end

  namespace :migrate do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Migrate #{name} database for current environment"
      task name => :load_config do
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do
          ActiveRecord::Tasks::DatabaseTasks.migrate
        end

        db_namespace["_dump:#{name}"].invoke
      end
    end

    desc "Roll back the database one migration and re-migrate up (options: STEP=x, VERSION=x)."
    task redo: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:migrate:redo")

      raise "Empty VERSION provided" if ENV["VERSION"] && ENV["VERSION"].empty?

      if ENV["VERSION"]
        db_namespace["migrate:down"].invoke
        db_namespace["migrate:up"].invoke
      else
        db_namespace["rollback"].invoke
        db_namespace["migrate"].invoke
      end
    end

    namespace :redo do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Roll back #{name} database one migration and re-migrate up (options: STEP=x, VERSION=x)."
        task name => :load_config do
          raise "Empty VERSION provided" if ENV["VERSION"] && ENV["VERSION"].empty?

          if ENV["VERSION"]
            db_namespace["migrate:down:#{name}"].invoke
            db_namespace["migrate:up:#{name}"].invoke
          else
            db_namespace["rollback:#{name}"].invoke
            db_namespace["migrate:#{name}"].invoke
          end
        end
      end
    end

    desc "Resets your database using your migrations for the current environment"
    task reset: ["db:drop", "db:create", "db:schema:dump", "db:migrate"]

    namespace :reset do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Drop and recreate the #{name} database using migrations"
        task name => :load_config do
          db_namespace["drop:#{name}"].invoke
          db_namespace["create:#{name}"].invoke
          db_namespace["schema:dump:#{name}"].invoke
          db_namespace["migrate:#{name}"].invoke
        end
      end
    end

    desc 'Run the "up" for a given migration VERSION.'
    task up: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:migrate:up")

      raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

      ActiveRecord::Tasks::DatabaseTasks.check_target_version

      ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool.migration_context.run(
        :up,
        ActiveRecord::Tasks::DatabaseTasks.target_version
      )
      db_namespace["_dump"].invoke
    end

    namespace :up do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Run the \"up\" on #{name} database for a given migration VERSION."
        task name => :load_config do
          raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do |pool|
            ActiveRecord::Tasks::DatabaseTasks.check_target_version
            pool.migration_context.run(:up, ActiveRecord::Tasks::DatabaseTasks.target_version)
          end

          db_namespace["_dump:#{name}"].invoke
        end
      end
    end

    desc 'Run the "down" for a given migration VERSION.'
    task down: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:migrate:down")

      raise "VERSION is required - To go down one migration, use db:rollback" if !ENV["VERSION"] || ENV["VERSION"].empty?

      ActiveRecord::Tasks::DatabaseTasks.check_target_version

      ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool.migration_context.run(
        :down,
        ActiveRecord::Tasks::DatabaseTasks.target_version
      )
      db_namespace["_dump"].invoke
    end

    namespace :down do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Run the \"down\" on #{name} database for a given migration VERSION."
        task name => :load_config do
          raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do |pool|
            ActiveRecord::Tasks::DatabaseTasks.check_target_version
            pool.migration_context.run(:down, ActiveRecord::Tasks::DatabaseTasks.target_version)
          end

          db_namespace["_dump:#{name}"].invoke
        end
      end
    end

    desc "Display status of migrations"
    task status: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each do
        ActiveRecord::Tasks::DatabaseTasks.migrate_status
      end
    end

    namespace :status do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Display status of migrations for #{name} database"
        task name => :load_config do
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do
            ActiveRecord::Tasks::DatabaseTasks.migrate_status
          end
        end
      end
    end
  end

  namespace :rollback do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Rollback #{name} database for current environment (specify steps w/ STEP=n)."
      task name => :load_config do
        step = ENV["STEP"] ? ENV["STEP"].to_i : 1

        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do |pool|
          pool.migration_context.rollback(step)
        end

        db_namespace["_dump:#{name}"].invoke
      end
    end
  end

  desc "Roll the schema back to the previous version (specify steps w/ STEP=n)."
  task rollback: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:rollback")
    raise "VERSION is not supported - To rollback a specific version, use db:migrate:down" if ENV["VERSION"]

    step = ENV["STEP"] ? ENV["STEP"].to_i : 1

    ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool.migration_context.rollback(step)

    db_namespace["_dump"].invoke
  end

  # desc 'Pushes the schema to the next version (specify steps w/ STEP=n).'
  task forward: :load_config do
    step = ENV["STEP"] ? ENV["STEP"].to_i : 1

    ActiveRecord::Tasks::DatabaseTasks.migration_connection_pool.migration_context.forward(step)

    db_namespace["_dump"].invoke
  end

  namespace :reset do
    task all: ["db:drop", "db:setup"]

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Drop and recreate the #{name} database from its schema for the current environment and load the seeds."
      task name => ["db:drop:#{name}", "db:setup:#{name}"]
    end
  end

  desc "Drop and recreate all databases from their schema for the current environment and load the seeds."
  task reset: [ "db:drop", "db:setup" ]

  # desc "Retrieve the charset for the current environment's database"
  task charset: :load_config do
    puts ActiveRecord::Tasks::DatabaseTasks.charset_current
  end

  # desc "Retrieve the collation for the current environment's database"
  task collation: :load_config do
    puts ActiveRecord::Tasks::DatabaseTasks.collation_current
  rescue NoMethodError
    $stderr.puts "Sorry, your database adapter is not supported yet. Feel free to submit a patch."
  end

  desc "Retrieve the current schema version number"
  task version: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env) do |pool|
      puts "\ndatabase: #{pool.db_config.database}\n"
      puts "Current version: #{pool.migration_context.current_version}"
      puts
    end
  end

  namespace :version do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Retrieve the current schema version number for #{name} database"
      task name => :load_config do
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_connection(db_config) do |connection|
          puts "Current version: #{connection.schema_version}"
        end
      end
    end
  end

  # desc "Raises an error if there are pending migrations"
  task abort_if_pending_migrations: :load_config do
    pending_migrations = []

    ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each do |pool|
      pending_migrations << pool.migration_context.open.pending_migrations
    end

    pending_migrations.flatten!

    if pending_migrations.any?
      puts "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}"

      pending_migrations.each do |pending_migration|
        puts "  %4d %s" % [pending_migration.version, pending_migration.name]
      end

      abort %{Run `bin/rails db:migrate` to update your database then try again.}
    end
  end

  namespace :abort_if_pending_migrations do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      # desc "Raise an error if there are pending migrations for #{name} database"
      task name => :load_config do
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: Rails.env, name: name) do |pool|
          pending_migrations = pool.migration_context.open.pending_migrations

          if pending_migrations.any?
            puts "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}"

            pending_migrations.each do |pending_migration|
              puts "  %4d %s" % [pending_migration.version, pending_migration.name]
            end

            abort %{Run `bin/rails db:migrate:#{name}` to update your database then try again.}
          end
        end
      end
    end
  end

  namespace :setup do
    task all: ["db:create", :environment, "db:schema:load", :seed]

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Create the #{name} database, load the schema, and initialize with the seed data (use db:reset:#{name} to also drop the database first)"
      task name => ["db:create:#{name}", :environment, "db:schema:load:#{name}", "db:seed"]
    end
  end

  desc "Create all databases, load all schemas, and initialize with the seed data (use db:reset to also drop all databases first)"
  task setup: ["db:create", :environment, "db:schema:load", :seed]

  desc "Run setup if database does not exist, or run migrations if it does"
  task prepare: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.prepare_all
  end

  desc "Load the seed data from db/seeds.rb"
  task seed: :load_config do
    db_namespace["abort_if_pending_migrations"].invoke
    ActiveRecord::Tasks::DatabaseTasks.load_seed
  end

  namespace :seed do
    desc "Truncate tables of each database for current environment and load the seeds"
    task replant: [:load_config, :truncate_all, :seed]
  end

  namespace :fixtures do
    desc "Load fixtures into the current environment's database. To load specific fixtures, use FIXTURES=x,y. To load from subdirectory in test/fixtures, use FIXTURES_DIR=z. To specify an alternative path (e.g. spec/fixtures), use FIXTURES_PATH=spec/fixtures."
    task load: :load_config do
      require "active_record/fixtures"

      base_dir = ActiveRecord::Tasks::DatabaseTasks.fixtures_path

      fixtures_dir = if ENV["FIXTURES_DIR"]
        File.join base_dir, ENV["FIXTURES_DIR"]
      else
        base_dir
      end

      fixture_files = if ENV["FIXTURES"]
        ENV["FIXTURES"].split(",")
      else
        files = Dir[File.join(fixtures_dir, "**/*.{yml}")]
        files.reject! { |f| f.start_with?(File.join(fixtures_dir, "files")) }
        files.map! { |f| f[fixtures_dir.to_s.size..-5].delete_prefix("/") }
      end

      ActiveRecord::FixtureSet.create_fixtures(fixtures_dir, fixture_files)
    end

    # desc "Search for a fixture given a LABEL or ID. Specify an alternative path (e.g. spec/fixtures) using FIXTURES_PATH=spec/fixtures."
    task identify: :load_config do
      require "active_record/fixtures"

      label, id = ENV["LABEL"], ENV["ID"]
      raise "LABEL or ID required" if label.blank? && id.blank?

      puts %Q(The fixture ID for "#{label}" is #{ActiveRecord::FixtureSet.identify(label)}.) if label

      base_dir = ActiveRecord::Tasks::DatabaseTasks.fixtures_path

      Dir["#{base_dir}/**/*.yml"].each do |file|
        if data = ActiveSupport::ConfigurationFile.parse(file)
          data.each_key do |key|
            key_id = ActiveRecord::FixtureSet.identify(key)

            if key == label || key_id == id.to_i
              puts "#{file}: #{key} (#{key_id})"
            end
          end
        end
      end
    end
  end

  namespace :schema do
    desc "Create a database schema file (either db/schema.rb or db/structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`)"
    task dump: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.dump_all

      db_namespace["schema:dump"].reenable
    end

    desc "Load a database schema file (either db/schema.rb or db/structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`) into the database"
    task load: [:load_config, :check_protected_environments] do
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current(ENV["SCHEMA_FORMAT"], ENV["SCHEMA"])
    end

    namespace :dump do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Create a database schema file (either db/schema.rb or db/structure.sql, depending on configuration) for #{name} database"
        task name => :load_config do
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(name: name) do |pool|
            db_config = pool.db_config
            ActiveRecord::Tasks::DatabaseTasks.dump_schema(db_config, ENV["SCHEMA_FORMAT"] || db_config.schema_format)
          end

          db_namespace["schema:dump:#{name}"].reenable
        end
      end
    end

    namespace :load do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Load a database schema file (either db/schema.rb or db/structure.sql, depending on configuration) into the #{name} database"
        task name => [:load_config, :check_protected_environments] do
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(name: name) do |pool|
            db_config = pool.db_config
            ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, ENV["SCHEMA_FORMAT"] || db_config.schema_format)
          end
        end
      end
    end

    namespace :cache do
      desc "Create a db/schema_cache.yml file."
      task dump: :load_config do
        ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each do |pool|
          db_config = pool.db_config
          filename = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(db_config)

          ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(pool, filename)
        end
      end

      desc "Clear a db/schema_cache.yml file."
      task clear: :load_config do
        ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
          filename = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(db_config)
          ActiveRecord::Tasks::DatabaseTasks.clear_schema_cache(
            filename,
          )
        end
      end
    end
  end

  namespace :encryption do
    desc "Generate a set of keys for configuring Active Record encryption in a given environment"
    task :init do
      puts <<~MSG
        Add this entry to the credentials of the target environment:#{' '}

        active_record_encryption:
          primary_key: #{SecureRandom.alphanumeric(32)}
          deterministic_key: #{SecureRandom.alphanumeric(32)}
          key_derivation_salt: #{SecureRandom.alphanumeric(32)}
      MSG
    end
  end

  namespace :test do
    # desc "Recreate the test database from an existent schema file (schema.rb or structure.sql, depending on configuration)"
    task load_schema: %w(db:test:purge) do
      ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test") do |pool|
        db_config = pool.db_config
        ActiveRecord::Schema.verbose = false
        ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, ENV["SCHEMA_FORMAT"] || db_config.schema_format)
      end
    end

    # desc "Empty the test database"
    task purge: %w(load_config check_protected_environments) do
      ActiveRecord::Base.configurations.configs_for(env_name: "test").each do |db_config|
        ActiveRecord::Tasks::DatabaseTasks.purge(db_config)
      end
    end

    # desc 'Load the test schema'
    task prepare: :load_config do
      unless ActiveRecord::Base.configurations.blank?
        db_namespace["test:load_schema"].invoke
      end
    end

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      # desc "Recreate the #{name} test database from an existent schema.rb file"
      namespace :load_schema do
        task name => "db:test:purge:#{name}" do
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test", name: name) do |pool|
            db_config = pool.db_config
            ActiveRecord::Schema.verbose = false
            ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, ENV["SCHEMA_FORMAT"] || db_config.schema_format)
          end
        end
      end

      # desc "Empty the #{name} test database"
      namespace :purge do
        task name => %w(load_config check_protected_environments) do
          ActiveRecord::Tasks::DatabaseTasks.with_temporary_pool_for_each(env: "test", name: name) do |pool|
            db_config = pool.db_config
            ActiveRecord::Tasks::DatabaseTasks.purge(db_config)
          end
        end
      end

      # desc 'Load the #{name} database test schema'
      namespace :prepare do
        task name => :load_config do
          db_namespace["test:load_schema:#{name}"].invoke
        end
      end
    end
  end
end

namespace :railties do
  namespace :install do
    # desc "Copy missing migrations from Railties (e.g. engines). You can specify Railties to use with FROM=railtie1,railtie2 and database to copy to with DATABASE=database."
    task migrations: :'db:load_config' do
      to_load = ENV["FROM"].blank? ? :all : ENV["FROM"].split(",").map(&:strip)
      railties = {}
      Rails.application.migration_railties.each do |railtie|
        next unless to_load == :all || to_load.include?(railtie.railtie_name)

        if railtie.respond_to?(:paths) && (path = railtie.paths["db/migrate"].first)
          railties[railtie.railtie_name] = path
        end

        unless ENV["MIGRATIONS_PATH"].blank?
          railties[railtie.railtie_name] = railtie.root + ENV["MIGRATIONS_PATH"]
        end
      end

      on_skip = Proc.new do |name, migration|
        puts "NOTE: Migration #{migration.basename} from #{name} has been skipped. Migration with the same name already exists."
      end

      on_copy = Proc.new do |name, migration|
        puts "Copied migration #{migration.basename} from #{name}"
      end

      if ENV["DATABASE"].present? && ENV["DATABASE"] != "primary"
        config = ActiveRecord::Base.configurations.configs_for(name: ENV["DATABASE"])
        raise "Invalid DATABASE provided" if config.blank?
        destination = config.migrations_paths
        raise "#{ENV["DATABASE"]} does not have a custom migration path" if destination.blank?
      else
        destination = ActiveRecord::Tasks::DatabaseTasks.migrations_paths.first
      end

      ActiveRecord::Migration.copy(destination, railties,
                                    on_skip: on_skip, on_copy: on_copy)
    end
  end
end
