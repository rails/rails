# frozen_string_literal: true

require "generators/generators_test_helper"
require "generators/action_mailbox/install/install_generator"

class ActionMailbox::Generators::InstallGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper

  def setup
    Rails.application = TestApp::Application
    Rails.application.config.root = Pathname(destination_root)

    production_env_config = Pathname("config/environments/production.rb").expand_path(destination_root)
    production_env_config.dirname.mkpath
    production_env_config.write <<~PRODUCTION
      Rails.application.configure do
      end
    PRODUCTION
  end

  def teardown
    Rails.application = Rails.application.instance
  end

  def test_create_action_mailbox_files
    with_database_configuration { run_generator }

    assert_file "app/mailboxes/application_mailbox.rb"
  end

  def test_add_action_mailbox_production_environment_config
    with_database_configuration { run_generator }

    assert_file "config/environments/production.rb" do |content|
      assert_match("Prepare the ingress controller used to receive mail", content)
      assert_match("config.action_mailbox.ingress = :relay", content)
    end
  end

  def test_create_migrations
    with_database_configuration { run_generator }

    assert_migration "db/migrate/create_active_storage_tables.active_storage.rb"
    assert_migration "db/migrate/create_action_mailbox_tables.action_mailbox.rb"
  end
end
