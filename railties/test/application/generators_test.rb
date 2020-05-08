# frozen_string_literal: true

require "isolation/abstract_unit"

module ApplicationTests
  class GeneratorsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
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
      rails "plugin", "new", "vendor/plugins/bukkits"
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
          g.orm    "data_mapper", migration: false
        end

        expected = {
          rails: { orm: :data_mapper },
          data_mapper: { migration: false }
        }

        assert_equal expected, c.generators.options
      end
    end

    test "api only generators hide assets, helper, js and css namespaces and set api option" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY

      # Initialize the application
      require "#{app_path}/config/environment"
      Rails.application.load_generators

      assert_includes Rails::Generators.hidden_namespaces, "assets"
      assert_includes Rails::Generators.hidden_namespaces, "helper"
      assert_includes Rails::Generators.hidden_namespaces, "js"
      assert_includes Rails::Generators.hidden_namespaces, "css"
      assert Rails::Generators.options[:rails][:api]
      assert_equal false, Rails::Generators.options[:rails][:assets]
      assert_equal false, Rails::Generators.options[:rails][:helper]
      assert_nil Rails::Generators.options[:rails][:template_engine]
    end

    test "api only generators allow overriding generator options" do
      add_to_config <<-RUBY
      config.generators.helper = true
      config.api_only = true
      config.generators.template_engine = :my_template
      RUBY

      # Initialize the application
      require "#{app_path}/config/environment"
      Rails.application.load_generators

      assert Rails::Generators.options[:rails][:api]
      assert Rails::Generators.options[:rails][:helper]
      assert_equal :my_template, Rails::Generators.options[:rails][:template_engine]
    end

    test "api only generator generate mailer views" do
      add_to_config <<-RUBY
        config.api_only = true
      RUBY

      rails "generate", "mailer", "notifier", "foo"
      assert File.exist?(File.join(rails_root, "app/views/notifier_mailer/foo.text.erb"))
      assert File.exist?(File.join(rails_root, "app/views/notifier_mailer/foo.html.erb"))
    end

    test "ARGV is populated" do
      require "#{app_path}/config/environment"
      Rails.application.load_generators

      class Rails::Generators::CheckArgvGenerator < Rails::Generators::Base
        def check_expected
          raise "ARGV.first is not expected" unless ARGV.first == "expected"
        end
      end

      quietly do
        Rails::Command.invoke(:generate, ["check_argv", "expected"]) # should not raise
      end
    end

    test "help does not show hidden namespaces and hidden commands" do
      FileUtils.cd(rails_root) do
        output = rails("generate", "--help")
        assert_no_match "active_record:migration", output
        assert_no_match "credentials", output

        output = rails("destroy", "--help")
        assert_no_match "active_record:migration", output
      end
    end

    test "skip collision check" do
      rails("generate", "model", "post", "title:string")

      output = rails("generate", "model", "post", "title:string", "body:string")
      assert_match(/The name 'Post' is either already used in your application or reserved/, output)

      output = rails("generate", "model", "post", "title:string", "body:string", "--skip-collision-check")
      assert_no_match(/The name 'Post' is either already used in your application or reserved/, output)
    end

    test "force" do
      rails("generate", "model", "post", "title:string")

      output = rails("generate", "model", "post", "title:string", "body:string")
      assert_match(/The name 'Post' is either already used in your application or reserved/, output)

      output = rails("generate", "model", "post", "title:string", "body:string", "--force")
      assert_no_match(/The name 'Post' is either already used in your application or reserved/, output)
    end

    test "generators with after_generate callback" do
      model_file = File.join(app_path, "app/models/post.rb")
      with_config do |c|
        c.generators.after_generate do |files|
          expected = %w(
            db/migrate/20000101000000_create_posts.rb
            app/models/post.rb
            test/models/post_test.rb
            test/fixtures/posts.yml
            app/controllers/posts_controller.rb
            app/views/posts/index.html.erb
            app/views/posts/edit.html.erb
            app/views/posts/show.html.erb
            app/views/posts/new.html.erb
            app/views/posts/_form.html.erb
            test/controllers/posts_controller_test.rb
            test/system/posts_test.rb
            app/helpers/posts_helper.rb
          )
          assert_equal expected, files

          File.open(model_file, "a") { |f| f.write("# Add comment to model") }
        end
      end

      travel_to Time.utc(2000, 1, 1)  do
        rails("generate", "scaffold", "post", "title:string")
      end

      assert_match(/# Add comment to model/, File.read(model_file))
    end
  end
end
