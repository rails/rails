# frozen_string_literal: true

require "generators/generators_test_helper"
require "rails/generators/rails/app/app_generator"

class ApiAppGeneratorTest < Rails::Generators::TestCase
  include GeneratorsTestHelper
  tests Rails::Generators::AppGenerator

  arguments [destination_root, "--api"]

  def setup
    Rails.application = TestApp::Application
    super

    Kernel.silence_warnings do
      Thor::Base.shell.attr_accessor :always_force
      @shell = Thor::Base.shell.new
      @shell.always_force = true
    end
  end

  def teardown
    super
    Rails.application = TestApp::Application.instance
  end

  def test_skeleton_is_created
    run_generator

    default_files.each { |path| assert_file path }
    skipped_files.each { |path| assert_no_file path }
  end

  def test_api_modified_files
    run_generator

    assert_file ".gitignore" do |content|
      assert_no_match(/\/public\/assets/, content)
    end

    assert_file "Gemfile" do |content|
      assert_no_match(/gem "sass-rails"/, content)
      assert_no_match(/gem "web-console"/, content)
      assert_no_match(/gem "capybara"/, content)
      assert_no_match(/gem "selenium-webdriver"/, content)
      assert_match(/# gem "jbuilder"/, content)
      assert_match(/# gem "rack-cors"/, content)
    end

    assert_file "config/application.rb", /config\.api_only = true/
    assert_file "app/controllers/application_controller.rb", /ActionController::API/

    assert_file "config/environments/development.rb" do |content|
      assert_no_match(/action_controller\.perform_caching = true/, content)
    end
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/action_controller\.perform_caching = true/, content)
    end
  end

  def test_generator_if_skip_action_cable_is_given
    run_generator [destination_root, "--api", "--skip-action-cable"]
    assert_file "config/application.rb", /#\s+require\s+["']action_cable\/engine["']/
    assert_no_file "config/cable.yml"
    assert_no_file "app/channels"
    assert_file "Gemfile" do |content|
      assert_no_match(/redis/, content)
    end
  end

  def test_generator_if_skip_action_mailer_is_given
    run_generator [destination_root, "--api", "--skip-action-mailer"]
    assert_file "config/application.rb", /#\s+require\s+["']action_mailer\/railtie["']/
    assert_file "config/environments/development.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "config/environments/test.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_file "config/environments/production.rb" do |content|
      assert_no_match(/config\.action_mailer/, content)
    end
    assert_no_directory "app/mailers"
    assert_no_directory "test/mailers"
    assert_no_directory "app/views"
  end

  def test_app_update_does_not_generate_unnecessary_config_files
    run_generator

    generator = Rails::Generators::AppGenerator.new ["rails"],
      { api: true, update: true }, { destination_root: destination_root, shell: @shell }
    quietly { generator.update_config_files }

    assert_no_file "config/initializers/cookies_serializer.rb"
    assert_no_file "config/initializers/assets.rb"
    assert_no_file "config/initializers/content_security_policy.rb"
    assert_no_file "config/initializers/permissions_policy.rb"
  end

  def test_app_update_does_not_generate_unnecessary_bin_files
    run_generator

    generator = Rails::Generators::AppGenerator.new ["rails"],
      { api: true, update: true }, { destination_root: destination_root, shell: @shell }
    quietly { generator.update_bin_files }

    assert_no_file "bin/yarn"
  end

  private
    def default_files
      %w(.gitignore
        .ruby-version
        README.md
        Gemfile
        Rakefile
        config.ru
        app/channels
        app/controllers
        app/mailers
        app/models
        app/views/layouts
        app/views/layouts/mailer.html.erb
        app/views/layouts/mailer.text.erb
        bin/rails
        bin/rake
        bin/setup
        config/application.rb
        config/boot.rb
        config/cable.yml
        config/environment.rb
        config/environments
        config/environments/development.rb
        config/environments/production.rb
        config/environments/test.rb
        config/initializers
        config/initializers/application_controller_renderer.rb
        config/initializers/backtrace_silencers.rb
        config/initializers/cors.rb
        config/initializers/filter_parameter_logging.rb
        config/initializers/inflections.rb
        config/initializers/mime_types.rb
        config/initializers/wrap_parameters.rb
        config/locales
        config/locales/en.yml
        config/puma.rb
        config/routes.rb
        config/credentials.yml.enc
        config/spring.rb
        config/storage.yml
        db
        db/seeds.rb
        lib
        lib/tasks
        log
        test/fixtures
        test/controllers
        test/integration
        test/models
        tmp
        vendor
      )
    end

    def skipped_files
      %w(app/assets
         app/helpers
         app/views/layouts/application.html.erb
         bin/yarn
         config/initializers/assets.rb
         config/initializers/cookies_serializer.rb
         config/initializers/content_security_policy.rb
         config/initializers/permissions_policy.rb
         lib/assets
         test/helpers
         tmp/cache/assets
         public/404.html
         public/422.html
         public/500.html
         public/apple-touch-icon-precomposed.png
         public/apple-touch-icon.png
         public/favicon.ico
         package.json
      )
    end
end
