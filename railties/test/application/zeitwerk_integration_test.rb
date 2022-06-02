# frozen_string_literal: true

require "set"
require "isolation/abstract_unit"

class ZeitwerkIntegrationTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::Isolation

  def setup
    build_app
  end

  def boot(env = "development")
    app(env)
  end

  def teardown
    teardown_app
  end

  def deps
    ActiveSupport::Dependencies
  end

  test "The integration is minimally looking good" do
    boot

    assert Rails.autoloaders.zeitwerk_enabled?
    assert_instance_of Zeitwerk::Loader, Rails.autoloaders.main
    assert_instance_of Zeitwerk::Loader, Rails.autoloaders.once
    assert_equal [Rails.autoloaders.main, Rails.autoloaders.once], Rails.autoloaders.to_a
  end

  test "autoloaders inflect with Active Support" do
    app_file "config/initializers/inflections.rb", <<-RUBY
      ActiveSupport::Inflector.inflections(:en) do |inflect|
        inflect.acronym 'RESTful'
      end
    RUBY

    app_file "app/controllers/restful_controller.rb", <<-RUBY
      class RESTfulController < ApplicationController
      end
    RUBY

    boot

    basename  = "restful_controller"
    abspath   = "#{Rails.root}/app/controllers/#{basename}.rb"
    camelized = "RESTfulController"

    Rails.autoloaders.each do |autoloader|
      assert_equal camelized, autoloader.inflector.camelize(basename, abspath)
    end

    assert RESTfulController
  end


  test "the once autoloader can autoload from initializers" do
    app_file "extras0/x.rb", "X = 0"
    app_file "extras1/y.rb", "Y = 0"

    # We should be able to configure autoload_once_paths in
    # config/application.rb and in config/environments/*.rb.
    add_to_config 'config.autoload_once_paths << "#{Rails.root}/extras0"'
    add_to_env_config "development", 'config.autoload_once_paths << "#{Rails.root}/extras1"'

    # Collections should br frozen after bootstrap, and you are ready to
    # autoload with the once autoloader. In particular, from initializers.
    $config_autoload_once_paths_is_frozen = false
    $global_autoload_once_paths_is_frozen = false
    add_to_config <<~RUBY
    initializer :test_autoload_once_paths_is_frozen, after: :bootstrap_hook do
      $config_autoload_once_paths_is_frozen = config.autoload_once_paths.frozen?
      $global_autoload_once_paths_is_frozen = ActiveSupport::Dependencies.autoload_once_paths.frozen?
      X
    end
    RUBY

    app_file "config/initializers/autoload_Y.rb", "Y"

    # Preconditions.
    assert_not Object.const_defined?(:X)
    assert_not Object.const_defined?(:Y)

    boot

    assert Object.const_defined?(:X)
    assert Object.const_defined?(:Y)
    assert $config_autoload_once_paths_is_frozen
    assert $global_autoload_once_paths_is_frozen
  end

  test "the once autoloader can eager load" do
    app_file "app/serializers/money_serializer.rb", "MoneySerializer = :dummy_value"

    add_to_config 'config.autoload_once_paths << "#{Rails.root}/app/serializers"'
    add_to_config 'config.eager_load_paths << "#{Rails.root}/app/serializers"'

    assert_not Object.const_defined?(:MoneySerializer)

    boot("production")

    assert Object.const_defined?(:MoneySerializer)
  end

  test "eager loading loads the application code" do
    $zeitwerk_integration_test_user = false
    $zeitwerk_integration_test_post = false

    app_file "app/models/user.rb", "class User; end; $zeitwerk_integration_test_user = true"
    app_file "app/models/post.rb", "class Post; end; $zeitwerk_integration_test_post = true"

    boot("production")

    assert $zeitwerk_integration_test_user
    assert $zeitwerk_integration_test_post
  end

  test "eager loading loads the application code if invoked manually too (regression test)" do
    $zeitwerk_integration_test_user = false
    $zeitwerk_integration_test_post = false

    app_file "app/models/user.rb", "class User; end; $zeitwerk_integration_test_user = true"
    app_file "app/models/post.rb", "class Post; end; $zeitwerk_integration_test_post = true"

    boot

    # Preconditions.
    assert_not $zeitwerk_integration_test_user
    assert_not $zeitwerk_integration_test_post

    Rails.application.eager_load!

    # Postconditions.
    assert $zeitwerk_integration_test_user
    assert $zeitwerk_integration_test_post
  end

  test "reloading is enabled if config.enable_reloading is true" do
    add_to_env_config "development", "config.enable_reloading = true"

    boot

    assert     Rails.autoloaders.main.reloading_enabled?
    assert_not Rails.autoloaders.once.reloading_enabled?
  end

  test "reloading is disabled if config.enable_reloading is false" do
    add_to_env_config "development", "config.enable_reloading = false"

    boot

    assert_not Rails.autoloaders.main.reloading_enabled?
    assert_not Rails.autoloaders.once.reloading_enabled?
  end

  test "eager loading loads code in engines" do
    $test_blog_engine_eager_loaded = false

    engine("blog") do |bukkit|
      bukkit.write("lib/blog.rb", "class BlogEngine < Rails::Engine; end")
      bukkit.write("app/models/post.rb", "Post = $test_blog_engine_eager_loaded = true")
    end

    boot("production")

    assert $test_blog_engine_eager_loaded
  end

  test "eager loading loads anything managed by Zeitwerk" do
    $zeitwerk_integration_test_user = false
    app_file "app/models/user.rb", "class User; end; $zeitwerk_integration_test_user = true"

    $zeitwerk_integration_test_extras = false
    app_dir "extras"
    app_file "extras/webhook_hacks.rb", "WebhookHacks = 1; $zeitwerk_integration_test_extras = true"

    require "zeitwerk"
    autoloader = Zeitwerk::Loader.new
    autoloader.push_dir("#{app_path}/extras")
    autoloader.setup

    boot("production")

    assert $zeitwerk_integration_test_user
    assert $zeitwerk_integration_test_extras
  end

  test "autoload directories not present in eager load paths are not eager loaded" do
    $zeitwerk_integration_test_user = false
    app_file "app/models/user.rb", "class User; end; $zeitwerk_integration_test_user = true"

    $zeitwerk_integration_test_lib = false
    app_dir "lib"
    app_file "lib/webhook_hacks.rb", "WebhookHacks = 1; $zeitwerk_integration_test_lib = true"

    $zeitwerk_integration_test_extras = false
    app_dir "extras"
    app_file "extras/websocket_hacks.rb", "WebsocketHacks = 1; $zeitwerk_integration_test_extras = true"

    add_to_config "config.autoload_paths      << '#{app_path}/lib'"
    add_to_config "config.autoload_once_paths << '#{app_path}/extras'"

    boot("production")

    assert $zeitwerk_integration_test_user
    assert_not $zeitwerk_integration_test_lib
    assert_not $zeitwerk_integration_test_extras

    assert WebhookHacks
    assert WebsocketHacks

    assert $zeitwerk_integration_test_lib
    assert $zeitwerk_integration_test_extras
  end

  test "autoload_paths not in autoload_once_paths are set as root dirs of main, and in the same order" do
    boot

    existing_autoload_paths = \
      deps.autoload_paths.select { |dir| File.directory?(dir) } -
      deps.autoload_once_paths
    assert_equal existing_autoload_paths, Rails.autoloaders.main.dirs
  end

  test "autoload_once_paths go to the once autoloader, and in the same order" do
    extras = %w(e1 e2 e3)
    extras.each do |extra|
      app_dir extra
      add_to_config %(config.autoload_once_paths << "\#{Rails.root}/#{extra}")
    end

    boot

    extras = extras.map { |extra| "#{app_path}/#{extra}" }
    extras.each do |extra|
      assert_not_includes Rails.autoloaders.main.dirs, extra
    end

    e1_index = Rails.autoloaders.once.dirs.index(extras.first)
    assert e1_index
    assert_equal extras, Rails.autoloaders.once.dirs.slice(e1_index, extras.length)
  end

  test "clear reloads the main autoloader, and does not reload the once one" do
    boot

    $zeitwerk_integration_reload_test = []

    main_autoloader = Rails.autoloaders.main
    def main_autoloader.reload
      $zeitwerk_integration_reload_test << :main_autoloader
      super
    end

    once_autoloader = Rails.autoloaders.once
    def once_autoloader.reload
      $zeitwerk_integration_reload_test << :once_autoloader
      super
    end

    ActiveSupport::Dependencies.clear

    assert_equal %i(main_autoloader), $zeitwerk_integration_reload_test
  end

  test "reloading eager loads again, if enabled" do
    add_to_env_config "development", "config.eager_load = true"

    $zeitwerk_integration_test_eager_load_count = 0
    app_file "app/models/user.rb", "class User; end; $zeitwerk_integration_test_eager_load_count += 1"

    boot
    assert_equal 1, $zeitwerk_integration_test_eager_load_count

    Rails.application.reloader.reload!
    assert_equal 2, $zeitwerk_integration_test_eager_load_count
  end

  test "reloading clears autoloaded tracked classes" do
    eval <<~RUBY
      class Parent
        extend ActiveSupport::DescendantsTracker
      end
    RUBY

    app_file "app/models/child.rb", <<~RUBY
      class Child < #{self.class.name}::Parent
      end
    RUBY

    app_file "app/models/grandchild.rb", <<~RUBY
      class Grandchild < Child
      end
    RUBY

    boot
    assert Grandchild

    # Preconditions, we add some redundancy about descendants tracking.
    assert_equal Set[Child, Grandchild], ActiveSupport::Dependencies._autoloaded_tracked_classes
    assert_equal [Child, Grandchild], Parent.descendants

    Rails.application.reloader.reload!

    assert_empty ActiveSupport::Dependencies._autoloaded_tracked_classes
    assert_equal [], Parent.descendants
  end

  test "autoloaders.logger=" do
    boot

    logger = ->(_msg) { }
    Rails.autoloaders.logger = logger

    Rails.autoloaders.each do |autoloader|
      assert_same logger, autoloader.logger
    end

    Rails.autoloaders.logger = Rails.logger

    Rails.autoloaders.each do |autoloader|
      assert_same Rails.logger, autoloader.logger
    end

    Rails.autoloaders.logger = nil

    Rails.autoloaders.each do |autoloader|
      assert_nil autoloader.logger
    end
  end

  test "autoloaders.log!" do
    app_file "extras/utils.rb", "module Utils; end"

    add_to_config %(config.autoload_once_paths << "\#{Rails.root}/extras")
    add_to_config "Rails.autoloaders.log!"

    out, _err = capture_io { boot }

    assert_match %r/^Zeitwerk@rails.main: autoload set for ApplicationRecord/, out
    assert_match %r/^Zeitwerk@rails.once: autoload set for Utils/, out
  end
end
