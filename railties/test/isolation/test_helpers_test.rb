# frozen_string_literal: true

require "isolation/abstract_unit"

module TestHelpersTests
  class GenerationTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def test_build_app
      build_app

      assert File.exist?("#{app_path}/config/database.yml")
      assert File.exist?("#{app_path}/config/routes.rb")
      assert File.exist?("#{app_path}/config/initializers")
    end

    def test_teardown_app
      build_app
      teardown_app

      assert_not File.exist?(app_path)
    end

    def test_add_to_config
      build_app

      config_file = "#{app_path}/config/application.rb"

      assert_not_empty File.open(config_file, &:read)

      add_to_config <<-RUBY
        config.zomg = 'zomg'
      RUBY

      config = File.open(config_file, &:read)

      # preserves indentation
      assert_match(/       config\.zomg = 'zomg'$/, config, "Expected `#{config_file}` to include `config.zomg = 'zomg'`, but did not:\n #{config}")
    end

    def test_remove_from_config
      build_app

      config_file = "#{app_path}/config/application.rb"

      assert_not_empty File.open(config_file, &:read)

      add_to_config <<-RUBY
        config.zomg = 'zomg'
      RUBY

      remove_from_config "config.zomg = 'zomg'"

      config = File.open(config_file, &:read)

      assert_no_match(/config\.zomg = 'zomg'$/, config, "Expected `#{config_file}` to include `config.zomg = 'zomg'`, but did not:\n #{config}")

      add_to_config <<-RUBY
        config.duplicates = :none
        config.duplicates = :none
      RUBY

      # removes all occurrences
      remove_from_config "config.duplicates = :none"

      config = File.open(config_file, &:read)

      assert_no_match(/config\.duplicates = :none$/, config, "Expected `#{config_file}` to include `config.duplicates = :none`, but did not:\n #{config}")
    end
  end
end
