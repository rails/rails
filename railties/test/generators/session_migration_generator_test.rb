require 'abstract_unit'
require 'generators/generators_test_helper'
require 'generators/rails/session_migration/session_migration_generator'

class SessionMigrationGeneratorTest < GeneratorsTestCase

  def test_session_migration_with_default_name
    run_generator
    assert_migration "db/migrate/add_sessions_table.rb", /class AddSessionsTable < ActiveRecord::Migration/
  end

  def test_session_migration_with_given_name
    run_generator ["create_session_table"]
    assert_migration "db/migrate/create_session_table.rb", /class CreateSessionTable < ActiveRecord::Migration/
  end

  protected

    def run_generator(args=[])
      silence(:stdout) { Rails::Generators::SessionMigrationGenerator.start args, :destination_root => destination_root }
    end

end
