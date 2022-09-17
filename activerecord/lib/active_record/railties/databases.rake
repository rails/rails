# frozen_string_literal: true

require "active_record"
require "active_support/configuration_file"
require "active_support/deprecation"

databases = ActiveRecord::Tasks::DatabaseTasks.setup_initial_database_yaml

db_namespace = namespace :db do
  desc "Set the environment value for the database"
  task "environment:set" => :load_config do
    connection = ActiveRecord::Base.connection
    raise ActiveRecord::EnvironmentStorageError unless connection.internal_metadata.enabled?

    connection.internal_metadata.create_table_and_set_flags(connection.migration_context.current_environment)
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

  desc "Creates the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:create:all to create all databases in the config). Without RAILS_ENV or when RAILS_ENV is development, it defaults to creating the development and test databases, except when DATABASE_URL is present."
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

  desc "Drops the database from DATABASE_URL or config/database.yml for the current RAILS_ENV (use db:drop:all to drop all databases in the config). Without RAILS_ENV or when RAILS_ENV is development, it defaults to dropping the development and test databases, except when DATABASE_URL is present."
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
    db_configs = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env)

    if db_configs.size == 1
      ActiveRecord::Tasks::DatabaseTasks.migrate
    else
      original_db_config = ActiveRecord::Base.connection_db_config
      mapped_versions = ActiveRecord::Tasks::DatabaseTasks.db_configs_with_versions(db_configs)

      mapped_versions.sort.each do |version, db_configs|
        db_configs.each do |db_config|
          ActiveRecord::Base.establish_connection(db_config)
          ActiveRecord::Tasks::DatabaseTasks.migrate(version)
        end
      end
    end

    db_namespace["_dump"].invoke
  ensure
    ActiveRecord::Base.establish_connection(original_db_config) if original_db_config
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
        original_db_config = ActiveRecord::Base.connection_db_config
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
        ActiveRecord::Base.establish_connection(db_config)
        ActiveRecord::Tasks::DatabaseTasks.migrate
        db_namespace["_dump:#{name}"].invoke
      ensure
        ActiveRecord::Base.establish_connection(original_db_config)
      end
    end

    desc "Rolls back the database one migration and re-migrates up (options: STEP=x, VERSION=x)."
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
        desc "Rolls back #{name} database one migration and re-migrates up (options: STEP=x, VERSION=x)."
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

    # desc 'Resets your database using your migrations for the current environment'
    task reset: ["db:drop", "db:create", "db:migrate"]

    desc 'Runs the "up" for a given migration VERSION.'
    task up: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:migrate:up")

      raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

      ActiveRecord::Tasks::DatabaseTasks.check_target_version

      ActiveRecord::Base.connection.migration_context.run(
        :up,
        ActiveRecord::Tasks::DatabaseTasks.target_version
      )
      db_namespace["_dump"].invoke
    end

    namespace :up do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc 'Runs the "up" on #{name} database for a given migration VERSION.'
        task name => :load_config do
          raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

          db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)

          ActiveRecord::Base.establish_connection(db_config)
          ActiveRecord::Tasks::DatabaseTasks.check_target_version
          ActiveRecord::Base.connection.migration_context.run(
            :up,
            ActiveRecord::Tasks::DatabaseTasks.target_version
          )

          db_namespace["_dump"].invoke
        end
      end
    end

    desc 'Runs the "down" for a given migration VERSION.'
    task down: :load_config do
      ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:migrate:down")

      raise "VERSION is required - To go down one migration, use db:rollback" if !ENV["VERSION"] || ENV["VERSION"].empty?

      ActiveRecord::Tasks::DatabaseTasks.check_target_version

      ActiveRecord::Base.connection.migration_context.run(
        :down,
        ActiveRecord::Tasks::DatabaseTasks.target_version
      )
      db_namespace["_dump"].invoke
    end

    namespace :down do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc 'Runs the "down" on #{name} database for a given migration VERSION.'
        task name => :load_config do
          raise "VERSION is required" if !ENV["VERSION"] || ENV["VERSION"].empty?

          db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)

          ActiveRecord::Base.establish_connection(db_config)
          ActiveRecord::Tasks::DatabaseTasks.check_target_version
          ActiveRecord::Base.connection.migration_context.run(
            :down,
            ActiveRecord::Tasks::DatabaseTasks.target_version
          )

          db_namespace["_dump"].invoke
        end
      end
    end

    desc "Display status of migrations"
    task status: :load_config do
      ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
        ActiveRecord::Base.establish_connection(db_config)
        ActiveRecord::Tasks::DatabaseTasks.migrate_status
      end
    end

    namespace :status do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Display status of migrations for #{name} database"
        task name => :load_config do
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
          ActiveRecord::Base.establish_connection(db_config)
          ActiveRecord::Tasks::DatabaseTasks.migrate_status
        end
      end
    end
  end

  namespace :rollback do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Rollback #{name} database for current environment (specify steps w/ STEP=n)."
      task name => :load_config do
        step = ENV["STEP"] ? ENV["STEP"].to_i : 1
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)

        ActiveRecord::Base.establish_connection(db_config)
        ActiveRecord::Base.connection.migration_context.rollback(step)

        db_namespace["_dump"].invoke
      end
    end
  end

  desc "Rolls the schema back to the previous version (specify steps w/ STEP=n)."
  task rollback: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.raise_for_multi_db(command: "db:rollback")
    raise "VERSION is not supported - To rollback a specific version, use db:migrate:down" if ENV["VERSION"]

    step = ENV["STEP"] ? ENV["STEP"].to_i : 1

    ActiveRecord::Base.connection.migration_context.rollback(step)

    db_namespace["_dump"].invoke
  end

  # desc 'Pushes the schema to the next version (specify steps w/ STEP=n).'
  task forward: :load_config do
    step = ENV["STEP"] ? ENV["STEP"].to_i : 1
    ActiveRecord::Base.connection.migration_context.forward(step)
    db_namespace["_dump"].invoke
  end

  namespace :reset do
    task all: ["db:drop", "db:setup"]

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Drops and recreates the #{name} database from its schema for the current environment and loads the seeds."
      task name => ["db:drop:#{name}", "db:setup:#{name}"]
    end
  end

  desc "Drops and recreates all databases from their schema for the current environment and loads the seeds."
  task reset: [ "db:drop", "db:setup" ]

  # desc "Retrieves the charset for the current environment's database"
  task charset: :load_config do
    puts ActiveRecord::Tasks::DatabaseTasks.charset_current
  end

  # desc "Retrieves the collation for the current environment's database"
  task collation: :load_config do
    puts ActiveRecord::Tasks::DatabaseTasks.collation_current
  rescue NoMethodError
    $stderr.puts "Sorry, your database adapter is not supported yet. Feel free to submit a patch."
  end

  desc "Retrieves the current schema version number"
  task version: :load_config do
    puts "Current version: #{ActiveRecord::Base.connection.schema_version}"
  end

  # desc "Raises an error if there are pending migrations"
  task abort_if_pending_migrations: :load_config do
    pending_migrations = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).flat_map do |db_config|
      ActiveRecord::Base.establish_connection(db_config)

      ActiveRecord::Base.connection.migration_context.open.pending_migrations
    end

    if pending_migrations.any?
      puts "You have #{pending_migrations.size} pending #{pending_migrations.size > 1 ? 'migrations:' : 'migration:'}"
      pending_migrations.each do |pending_migration|
        puts "  %4d %s" % [pending_migration.version, pending_migration.name]
      end
      abort %{Run `bin/rails db:migrate` to update your database then try again.}
    end
  ensure
    ActiveRecord::Base.establish_connection(ActiveRecord::Tasks::DatabaseTasks.env.to_sym)
  end

  namespace :abort_if_pending_migrations do
    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      # desc "Raises an error if there are pending migrations for #{name} database"
      task name => :load_config do
        db_config = ActiveRecord::Base.configurations.configs_for(env_name: Rails.env, name: name)
        ActiveRecord::Base.establish_connection(db_config)

        pending_migrations = ActiveRecord::Base.connection.migration_context.open.pending_migrations

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

  namespace :setup do
    task all: ["db:create", :environment, "db:schema:load", :seed]

    ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
      desc "Creates the #{name} database, loads the schema, and initializes with the seed data (use db:reset:#{name} to also drop the database first)"
      task name => ["db:create:#{name}", :environment, "db:schema:load:#{name}", "db:seed"]
    end
  end

  desc "Creates all databases, loads all schemas, and initializes with the seed data (use db:reset to also drop all databases first)"
  task setup: ["db:create", :environment, "db:schema:load", :seed]

  desc "Runs setup if database does not exist, or runs migrations if it does"
  task prepare: :load_config do
    ActiveRecord::Tasks::DatabaseTasks.prepare_all
  end

  desc "Loads the seed data from db/seeds.rb"
  task seed: :load_config do
    db_namespace["abort_if_pending_migrations"].invoke
    ActiveRecord::Tasks::DatabaseTasks.load_seed
  end

  namespace :seed do
    desc "Truncates tables of each database for current environment and loads the seeds"
    task replant: [:load_config, :truncate_all, :seed]
  end

  namespace :fixtures do
    desc "Loads fixtures into the current environment's database. Load specific fixtures using FIXTURES=x,y. Load from subdirectory in test/fixtures using FIXTURES_DIR=z. Specify an alternative path (e.g. spec/fixtures) using FIXTURES_PATH=spec/fixtures."
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
    desc "Creates a database schema file (either db/schema.rb or db/structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`)"
    task dump: :load_config do
      ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
        if db_config.schema_dump
          ActiveRecord::Base.establish_connection(db_config)
          schema_format = ENV.fetch("SCHEMA_FORMAT", ActiveRecord.schema_format).to_sym
          ActiveRecord::Tasks::DatabaseTasks.dump_schema(db_config, schema_format)
        end
      end

      db_namespace["schema:dump"].reenable
    end

    desc "Loads a database schema file (either db/schema.rb or db/structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`) into the database"
    task load: [:load_config, :check_protected_environments] do
      ActiveRecord::Tasks::DatabaseTasks.load_schema_current(ActiveRecord.schema_format, ENV["SCHEMA"])
    end

    namespace :dump do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Creates a database schema file (either db/schema.rb or db/structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`) for #{name} database"
        task name => :load_config do
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env, name: name)

          if db_config.schema_dump
            schema_format = ENV.fetch("SCHEMA_FORMAT", ActiveRecord.schema_format).to_sym

            ActiveRecord::Base.establish_connection(db_config)
            ActiveRecord::Tasks::DatabaseTasks.dump_schema(db_config, schema_format)
          end

          db_namespace["schema:dump:#{name}"].reenable
        end
      end
    end

    namespace :load do
      ActiveRecord::Tasks::DatabaseTasks.for_each(databases) do |name|
        desc "Loads a database schema file (either db/schema.rb or db/structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`) into the #{name} database"
        task name => "db:test:purge:#{name}" do
          original_db_config = ActiveRecord::Base.connection_db_config
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env, name: name)
          schema_format = ENV.fetch("SCHEMA_FORMAT", ActiveRecord.schema_format).to_sym
          ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, schema_format)
        ensure
          ActiveRecord::Base.establish_connection(original_db_config) if original_db_config
        end
      end
    end

    namespace :cache do
      desc "Creates a db/schema_cache.yml file."
      task dump: :load_config do
        ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
          ActiveRecord::Base.establish_connection(db_config)
          filename = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(
            db_config.name,
            schema_cache_path: db_config.schema_cache_path,
          )
          ActiveRecord::Tasks::DatabaseTasks.dump_schema_cache(
            ActiveRecord::Base.connection,
            filename,
          )
        end
      end

      desc "Clears a db/schema_cache.yml file."
      task clear: :load_config do
        ActiveRecord::Base.configurations.configs_for(env_name: ActiveRecord::Tasks::DatabaseTasks.env).each do |db_config|
          filename = ActiveRecord::Tasks::DatabaseTasks.cache_dump_filename(
            db_config.name,
            schema_cache_path: db_config.schema_cache_path,
          )
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
    # desc "Recreate the test database from an existent schema file (schema.rb or structure.sql, depending on `ENV['SCHEMA_FORMAT']` or `config.active_record.schema_format`)"
    task load_schema: %w(db:test:purge) do
      should_reconnect = ActiveRecord::Base.connection_pool.active_connection?
      ActiveRecord::Schema.verbose = false
      ActiveRecord::Base.configurations.configs_for(env_name: "test").each do |db_config|
        schema_format = ENV.fetch("SCHEMA_FORMAT", ActiveRecord.schema_format).to_sym
        ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, schema_format)
      end
    ensure
      if should_reconnect
        ActiveRecord::Base.establish_connection(ActiveRecord::Tasks::DatabaseTasks.env.to_sym)
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
          should_reconnect = ActiveRecord::Base.connection_pool.active_connection?
          ActiveRecord::Schema.verbose = false
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: name)
          schema_format = ENV.fetch("SCHEMA_FORMAT", ActiveRecord.schema_format).to_sym
          ActiveRecord::Tasks::DatabaseTasks.load_schema(db_config, schema_format)
        ensure
          if should_reconnect
            ActiveRecord::Base.establish_connection(ActiveRecord::Tasks::DatabaseTasks.env.to_sym)
          end
        end
      end

      # desc "Empty the #{name} test database"
      namespace :purge do
        task name => %w(load_config check_protected_environments) do
          original_db_config = ActiveRecord::Base.connection_db_config
          db_config = ActiveRecord::Base.configurations.configs_for(env_name: "test", name: name)
          ActiveRecord::Tasks::DatabaseTasks.purge(db_config)
        ensure
          ActiveRecord::Base.establish_connection(original_db_config) if original_db_config
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
    # desc "Copies missing migrations from Railties (e.g. engines). You can specify Railties to use with FROM=railtie1,railtie2"
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

      ActiveRecord::Migration.copy(ActiveRecord::Tasks::DatabaseTasks.migrations_paths.first, railties,
                                    on_skip: on_skip, on_copy: on_copy)
    end
  end
end
