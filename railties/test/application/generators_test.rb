require "isolation/abstract_unit"

module ApplicationTests
  class GeneratorsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
    end

    def teardown
      teardown_app
    end

    def app_const
      @app_const ||= Class.new(Rails::Application)
    end

    def with_config
      require "rails/all"
      require "rails/generators"
      yield app_const.config
    end

    def with_bare_config
      require "rails"
      require "rails/generators"
      yield app_const.config
    end

    test "allow running plugin new generator inside Rails app directory" do
      FileUtils.cd(rails_root){ `ruby script/rails plugin new vendor/plugins/bukkits` }
      assert File.exist?(File.join(rails_root, "vendor/plugins/bukkits/test/dummy/config/application.rb"))
    end

    test "generators default values" do
      with_bare_config do |c|
        assert_equal(true, c.generators.colorize_logging)
        assert_equal({}, c.generators.aliases)
        assert_equal({}, c.generators.options)
        assert_equal({}, c.generators.fallbacks)
      end
    end

    test "generators set rails options" do
      with_bare_config do |c|
        c.generators.orm            = :data_mapper
        c.generators.test_framework = :rspec
        c.generators.helper         = false
        expected = { rails: { orm: :data_mapper, test_framework: :rspec, helper: false } }
        assert_equal(expected, c.generators.options)
      end
    end

    test "generators set rails aliases" do
      with_config do |c|
        c.generators.aliases = { rails: { test_framework: "-w" } }
        expected = { rails: { test_framework: "-w" } }
        assert_equal expected, c.generators.aliases
      end
    end

    test "generators aliases, options, templates and fallbacks on initialization" do
      add_to_config <<-RUBY
        config.generators.rails aliases: { test_framework: "-w" }
        config.generators.orm :data_mapper
        config.generators.test_framework :rspec
        config.generators.fallbacks[:shoulda] = :test_unit
        config.generators.templates << "some/where"
      RUBY

      # Initialize the application
      require "#{app_path}/config/environment"
      Rails.application.load_generators

      assert_equal :rspec, Rails::Generators.options[:rails][:test_framework]
      assert_equal "-w", Rails::Generators.aliases[:rails][:test_framework]
      assert_equal Hash[shoulda: :test_unit], Rails::Generators.fallbacks
      assert_equal ["some/where"], Rails::Generators.templates_path
    end

    test "generators no color on initialization" do
      add_to_config <<-RUBY
        config.generators.colorize_logging = false
      RUBY

      # Initialize the application
      require "#{app_path}/config/environment"
      Rails.application.load_generators

      assert_equal Thor::Base.shell, Thor::Shell::Basic
    end

    test "generators with hashes for options and aliases" do
      with_bare_config do |c|
        c.generators do |g|
          g.orm    :data_mapper, migration: false
          g.plugin aliases: { generator: "-g" },
                   generator: true
        end

        expected = {
          rails: { orm: :data_mapper },
          plugin: { generator: true },
          data_mapper: { migration: false }
        }

        assert_equal expected, c.generators.options
        assert_equal({ plugin: { generator: "-g" } }, c.generators.aliases)
      end
    end

    test "generators with string and hash for options should generate symbol keys" do
      with_bare_config do |c|
        c.generators do |g|
          g.orm    'data_mapper', migration: false
        end

        expected = {
          rails: { orm: :data_mapper },
          data_mapper: { migration: false }
        }

        assert_equal expected, c.generators.options
      end
    end
  end
end
