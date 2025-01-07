# frozen_string_literal: true

require "isolation/abstract_unit"
require "rack/test"
require "rails-dom-testing"

module ApplicationTests
  class ValidatingServiceTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation
    include Rack::Test::Methods
    include Rails::Dom::Testing::Assertions

    self.file_fixture_path = "#{RAILS_FRAMEWORK_ROOT}/activestorage/test/fixtures/files"

    def setup
      build_app
    end

    def teardown
      teardown_app
    end

    def test_boot_application_with_model_using_active_storage_should_not_load_active_storage_blob
      rails "active_storage:install"

      rails "generate", "model", "user", "name:string", "avatar:attachment"
      rails "db:migrate"

      app_file "config/routes.rb", <<~RUBY
        Rails.application.routes.draw do
          _ = User
          resources :users, only: [:show, :create]
          Rails.configuration.ok_to_proceed = true
        end
      RUBY

      app_file "config/initializers/active_storage.rb", <<~RUBY
        Rails.configuration.ok_to_proceed = false

        ActiveSupport.on_load(:active_storage_blob) do
          raise "ActiveStorage::Blob was loaded" unless Rails.configuration.ok_to_proceed
        end
      RUBY

      assert_nothing_raised do
        with_env "RAILS_ENV" => "production" do
          rails ["environment", "--trace"]
        end
      end
    end
  end
end
