require "isolation/abstract_unit"

module ApplicationTests
  class GeneratorsTest < Test::Unit::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      boot_rails
      require "rails"
      require "rails/generators"
    end

    test "generators default values" do
      Rails::Initializer.run do |c|
        assert_equal(true, c.generators.colorize_logging)
        assert_equal({}, c.generators.aliases)
        assert_equal({}, c.generators.options)
      end
    end

    test "generators set rails options" do
      Rails::Initializer.run do |c|
        c.generators.orm            = :datamapper
        c.generators.test_framework = :rspec
        expected = { :rails => { :orm => :datamapper, :test_framework => :rspec } }
        assert_equal(expected, c.generators.options)
      end
    end

    test "generators set rails aliases" do
      Rails::Initializer.run do |c|
        c.generators.aliases = { :rails => { :test_framework => "-w" } }
        expected = { :rails => { :test_framework => "-w" } }
        assert_equal expected, c.generators.aliases
      end
    end

    test "generators aliases and options on initialization" do
      Rails::Initializer.run do |c|
        c.frameworks = []
        c.generators.rails :aliases => { :test_framework => "-w" }
        c.generators.orm :datamapper
        c.generators.test_framework :rspec
      end
      # Initialize the application
      Rails.initialize!

      assert_equal :rspec, Rails::Generators.options[:rails][:test_framework]
      assert_equal "-w", Rails::Generators.aliases[:rails][:test_framework]
    end

    test "generators no color on initialization" do
      Rails::Initializer.run do |c|
        c.frameworks = []
        c.generators.colorize_logging = false
      end
      # Initialize the application
      Rails.initialize!

      assert_equal Thor::Base.shell, Thor::Shell::Basic
    end

    test "generators with hashes for options and aliases" do
      Rails::Initializer.run do |c|
        c.generators do |g|
          g.orm    :datamapper, :migration => false
          g.plugin :aliases => { :generator => "-g" },
                   :generator => true
        end

        expected = {
          :rails => { :orm => :datamapper },
          :plugin => { :generator => true },
          :datamapper => { :migration => false }
        }

        assert_equal expected, c.generators.options
        assert_equal({ :plugin => { :generator => "-g" } }, c.generators.aliases)
      end
    end

    test "generators with hashes are deep merged" do
      Rails::Initializer.run do |c|
        c.generators do |g|
          g.orm    :datamapper, :migration => false
          g.plugin :aliases => { :generator => "-g" },
                   :generator => true
        end
      end

      assert Rails::Generators.aliases.size >= 1
      assert Rails::Generators.options.size >= 1
    end
  end
end