# frozen_string_literal: true

require "generators/generators_test_helper"
require "generators/active_storage/install/install_generator"

class ActiveStorage::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  setup do
    Rails.application = Rails.application.class
    Rails.application.config.root = Pathname(destination_root)
  end

  teardown do
     Rails.application = Rails.application.instance
   end

  test "creates migrations" do
    with_database_configuration do
      run_generator_instance
    end

    assert_migration "db/migrate/create_active_storage_tables.active_storage.rb"
  end

  test "creates fixtures" do
    with_database_configuration do
      run_generator_instance
    end

    assert_file "test/fixtures/active_storage/blobs.yml"
  end
end
