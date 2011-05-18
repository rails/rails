require 'generators/generators_test_helper'
require 'rails/generators/rails/session_migration/session_migration_generator'

class SessionMigrationGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def test_session_migration_with_default_name
    run_generator
    assert_migration "db/migrate/add_sessions_table.rb", /class AddSessionsTable < ActiveRecord::Migration/
  end

  def test_session_migration_with_given_name
    run_generator ["create_session_table"]
    assert_migration "db/migrate/create_session_table.rb", /class CreateSessionTable < ActiveRecord::Migration/
  end

  def test_session_migration_with_custom_table_name
    ActiveRecord::SessionStore::Session.table_name = "custom_table_name"
    run_generator
    assert_migration "db/migrate/add_sessions_table.rb" do |migration|
      assert_match(/class AddSessionsTable < ActiveRecord::Migration/, migration)
      assert_match(/create_table :custom_table_name/, migration)
    end
  ensure
    ActiveRecord::SessionStore::Session.table_name = "sessions"
  end
end
