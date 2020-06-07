# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/migration/migration_generator"

class CreateMigrationTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  class Migrator < Rails::Generators::MigrationGenerator
    include Rails::Generators::Migration

    def self.next_migration_number(dirname)
      current_migration_number(dirname) + 1
    end
  end

  tests Migrator

  def default_destination_path
    "db/migrate/create_articles.rb"
  end

  def create_migration(destination_path = default_destination_path, config = {}, generator_options = {}, &block)
    migration_name = File.basename(destination_path, ".rb")
    generator([migration_name], generator_options)
    generator.set_migration_assigns!(destination_path)

    dir, base = File.split(destination_path)
    timestamped_destination_path = File.join(dir, ["%migration_number%", base].join("_"))

    @migration = Rails::Generators::Actions::CreateMigration.new(generator, timestamped_destination_path, block || "contents", config)
  end

  def migration_exists!(*args)
    @existing_migration = create_migration(*args)
    invoke!
    @generator = nil
  end

  def invoke!
    capture(:stdout) { @migration.invoke! }
  end

  def revoke!
    capture(:stdout) { @migration.revoke! }
  end

  def test_invoke
    create_migration

    assert_match(/create  db\/migrate\/1_create_articles\.rb\n/, invoke!)
    assert_file @migration.destination
  end

  def test_invoke_pretended
    create_migration(default_destination_path, {}, { pretend: true })

    assert_no_file @migration.destination
  end

  def test_invoke_when_exists
    migration_exists!
    create_migration

    assert_equal @existing_migration.destination, @migration.existing_migration
  end

  def test_invoke_when_exists_identical
    migration_exists!
    create_migration

    assert_match(/identical  db\/migrate\/1_create_articles\.rb\n/, invoke!)
    assert_predicate @migration, :identical?
  end

  def test_invoke_return_existing_file_when_exists_identical
    migration_exists!
    create_migration

    invoked_file = nil
    quietly { invoked_file = @migration.invoke! }
    assert_equal @existing_migration.relative_existing_migration, invoked_file
  end

  def test_invoke_when_exists_not_identical
    migration_exists!
    create_migration { "different content" }

    assert_raise(Rails::Generators::Error) { invoke! }
  end

  def test_invoke_forced_when_exists_not_identical
    dest = "db/migrate/migration.rb"
    migration_exists!(dest)
    create_migration(dest, force: true) { "different content" }

    stdout = invoke!
    assert_match(/remove  db\/migrate\/1_migration\.rb\n/, stdout)
    assert_match(/create  db\/migrate\/2_migration\.rb\n/, stdout)
    assert_file @migration.destination
    assert_no_file @existing_migration.destination
  end

  def test_invoke_forced_pretended_when_exists_not_identical
    migration_exists!
    create_migration(default_destination_path, { force: true }, { pretend: true }) do
      "different content"
    end

    stdout = invoke!
    assert_match(/remove  db\/migrate\/1_create_articles\.rb\n/, stdout)
    assert_match(/create  db\/migrate\/2_create_articles\.rb\n/, stdout)
    assert_no_file @migration.destination
  end

  def test_invoke_skipped_when_exists_not_identical
    migration_exists!
    create_migration(default_destination_path, {}, { skip: true }) { "different content" }

    assert_match(/skip  db\/migrate\/2_create_articles\.rb\n/, invoke!)
    assert_no_file @migration.destination
  end

  def test_revoke
    migration_exists!
    create_migration

    assert_match(/remove  db\/migrate\/1_create_articles\.rb\n/, revoke!)
    assert_no_file @existing_migration.destination
  end

  def test_revoke_pretended
    migration_exists!
    create_migration(default_destination_path, {}, { pretend: true })

    assert_match(/remove  db\/migrate\/1_create_articles\.rb\n/, revoke!)
    assert_file @existing_migration.destination
  end

  def test_revoke_when_no_exists
    create_migration

    assert_match(/remove  db\/migrate\/1_create_articles\.rb\n/, revoke!)
  end
end
