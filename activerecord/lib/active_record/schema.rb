
module ActiveRecord
  # = Active Record Schema
  #
  # Allows programmers to programmatically define a schema in a portable
  # DSL. This means you can define tables, indexes, etc. without using SQL
  # directly, so your applications can more easily support multiple
  # databases.
  #
  # Usage:
  #
  #   ActiveRecord::Schema.define do
  #     create_table :authors do |t|
  #       t.string :name, null: false
  #     end
  #
  #     add_index :authors, :name, :unique
  #
  #     create_table :posts do |t|
  #       t.integer :author_id, null: false
  #       t.string :subject
  #       t.text :body
  #       t.boolean :private, default: false
  #     end
  #
  #     add_index :posts, :author_id
  #   end
  #
  # ActiveRecord::Schema is only supported by database adapters that also
  # support migrations, the two features being very similar.
  class Schema < Migration

    # Returns the migrations paths.
    #
    #   ActiveRecord::Schema.new.migrations_paths
    #   # => ["db/migrate"] # Rails migration path by default.
    def migrations_paths
      ActiveRecord::Migrator.migrations_paths
    end

    def define(info, &block) # :nodoc:
      @using_deprecated_version_setting = info[:version].present?
      SchemaMigration.drop_table
      initialize_schema_migrations_table

      instance_eval(&block)

      # handle files from pre-4.0 that used :version option instead of dumping migration table
      assume_migrated_upto_version(info[:version], migrations_paths) if @using_deprecated_version_setting
    end

    # Eval the given block. All methods available to the current connection
    # adapter are available within the block, so you can easily use the
    # database definition DSL to build up your schema (+create_table+,
    # +add_index+, etc.).
    def self.define(info={}, &block)
      new.define(info, &block)
    end

    # Create schema migration history. Include migration statements in a block to this method.
    #
    #   migrations do
    #     migration 20121128235959, "44f1397e3b92442ca7488a029068a5ad", "add_horn_color_to_unicorns"
    #     migration 20121129235959, "4a1eb3965d94406b00002b370854eae8", "add_magic_power_to_unicorns"
    #   end
    def migrations
      raise(ArgumentError, "Can't set migrations while using :version option") if @using_deprecated_version_setting
      yield
    end

    # Add a migration to the ActiveRecord::SchemaMigration table.
    #
    # The +version+ argument is an integer.
    # The +fingerprint+ and +name+ arguments are required but may be empty strings.
    # The migration's +migrated_at+ attribute is set to the current time,
    # instead of being set explicitly as an argument to the method.
    #
    #   migration 20121129235959, "4a1eb3965d94406b00002b370854eae8", "add_magic_power_to_unicorns"
    def migration(version, fingerprint, name)
      SchemaMigration.create!(version: version, migrated_at: Time.now, fingerprint: fingerprint, name: name)
    end
  end
end
