# frozen_string_literal: true

require "isolation/abstract_unit"
require "active_support/dependencies/zeitwerk_integration"

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

  def decorated?
    deps.singleton_class < deps::ZeitwerkIntegration::Decorations
  end

  test "ActiveSupport::Dependencies is decorated by default" do
    boot

    assert decorated?
    assert Rails.autoloaders.zeitwerk_enabled?
    assert_instance_of Zeitwerk::Loader, Rails.autoloaders.main
    assert_instance_of Zeitwerk::Loader, Rails.autoloaders.once
    assert_equal [Rails.autoloaders.main, Rails.autoloaders.once], Rails.autoloaders.to_a
  end

  test "ActiveSupport::Dependencies is not decorated in classic mode" do
    add_to_config "config.autoloader = :classic"
    boot

    assert_not decorated?
    assert_not Rails.autoloaders.zeitwerk_enabled?
    assert_nil Rails.autoloaders.main
    assert_nil Rails.autoloaders.once
    assert_equal 0, Rails.autoloaders.count
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

  test "constantize returns the value stored in the constant" do
    app_file "app/models/admin/user.rb", "class Admin::User; end"
    boot

    assert_same Admin::User, deps.constantize("Admin::User")
  end

  test "constantize raises if the constant is unknown" do
    boot

    assert_raises(NameError) { deps.constantize("Admin") }
  end

  test "safe_constantize returns the value stored in the constant" do
    app_file "app/models/admin/user.rb", "class Admin::User; end"
    boot

    assert_same Admin::User, deps.safe_constantize("Admin::User")
  end

  test "safe_constantize returns nil for unknown constants" do
    boot

    assert_nil deps.safe_constantize("Admin")
  end

  test "to_unload? says if a constant would be unloaded (main)" do
    app_file "app/models/user.rb", "class User; end"
    app_file "app/models/post.rb", "class Post; end"
    boot

    assert Post
    assert deps.to_unload?("Post")
    assert_not deps.to_unload?("User")
  end

  test "to_unload? says if a constant would be unloaded (once)" do
    add_to_config 'config.autoload_once_paths << "#{Rails.root}/extras"'
    app_file "extras/foo.rb", "class Foo; end"
    app_file "extras/bar.rb", "class Bar; end"
    boot

    assert Foo
    assert_not deps.to_unload?("Foo")
    assert_not deps.to_unload?("Bar")
  end

  test "to_unload? says if a constant would be unloaded (reloading disabled)" do
    app_file "app/models/user.rb", "class User; end"
    app_file "app/models/post.rb", "class Post; end"
    boot("production")

    assert Post
    assert_not deps.to_unload?("Post")
    assert_not deps.to_unload?("User")
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

  test "reloading is enabled if config.cache_classes is false" do
    boot

    assert     Rails.autoloaders.main.reloading_enabled?
    assert_not Rails.autoloaders.once.reloading_enabled?
  end

  test "reloading is disabled if config.cache_classes is true" do
    boot("production")

    assert_not Rails.autoloaders.main.reloading_enabled?
    assert_not Rails.autoloaders.once.reloading_enabled?
  end

  test "reloading raises if config.cache_classes is true" do
    boot("production")

    e = assert_raises(StandardError) do
      deps.clear
    end
    assert_equal "reloading is disabled because config.cache_classes is true", e.message
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

  test "autoload_paths are set as root dirs of main, and in the same order" do
    boot

    existing_autoload_paths = deps.autoload_paths.select { |dir| File.directory?(dir) }
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
    assert_equal extras, Rails.autoloaders.once.dirs
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

  test "verbose = true sets the dependencies logger if present" do
    boot

    logger = Logger.new(File::NULL)
    ActiveSupport::Dependencies.logger = logger
    ActiveSupport::Dependencies.verbose = true

    Rails.autoloaders.each do |autoloader|
      assert_same logger, autoloader.logger
    end
  end

  test "verbose = true sets the Rails logger as fallback" do
    boot

    ActiveSupport::Dependencies.verbose = true

    Rails.autoloaders.each do |autoloader|
      assert_same Rails.logger, autoloader.logger
    end
  end

  test "verbose = false sets loggers to nil" do
    boot

    ActiveSupport::Dependencies.verbose = true
    Rails.autoloaders.each do |autoloader|
      assert autoloader.logger
    end

    ActiveSupport::Dependencies.verbose = false
    Rails.autoloaders.each do |autoloader|
      assert_nil autoloader.logger
    end
  end

  test "unhooks" do
    boot

    assert_equal Module, Module.method(:const_missing).owner
    assert_equal :no_op, deps.unhook!
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

  # This is here because to guarantee classic mode works as always, Zeitwerk
  # integration does not touch anything in classic. The descendants tracker is a
  # very small one-liner exception. We leave its main test suite untouched, and
  # add some minimal safety net here.
  #
  # When time passes, things are going to be reorganized (famous last words).
  test "descendants tracker" do
    class ::ZeitwerkDTIntegrationTestRoot
      extend ActiveSupport::DescendantsTracker
    end
    class ::ZeitwerkDTIntegrationTestChild < ::ZeitwerkDTIntegrationTestRoot; end
    class ::ZeitwerkDTIntegrationTestGrandchild < ::ZeitwerkDTIntegrationTestChild; end

    begin
      app_file "app/models/user.rb", "class User < ZeitwerkDTIntegrationTestRoot; end"
      app_file "app/models/post.rb", "class Post < ZeitwerkDTIntegrationTestRoot; end"
      app_file "app/models/tutorial.rb", "class Tutorial < Post; end"
      boot

      assert User
      assert Tutorial

      direct_descendants = [ZeitwerkDTIntegrationTestChild, User, Post].to_set
      assert_equal direct_descendants, ZeitwerkDTIntegrationTestRoot.direct_descendants.to_set

      descendants = direct_descendants.merge([ZeitwerkDTIntegrationTestGrandchild, Tutorial])
      assert_equal descendants, ZeitwerkDTIntegrationTestRoot.descendants.to_set

      ActiveSupport::DescendantsTracker.clear

      direct_descendants = [ZeitwerkDTIntegrationTestChild].to_set
      assert_equal direct_descendants, ZeitwerkDTIntegrationTestRoot.direct_descendants.to_set

      descendants = direct_descendants.merge([ZeitwerkDTIntegrationTestGrandchild])
      assert_equal descendants, ZeitwerkDTIntegrationTestRoot.descendants.to_set
    ensure
      Object.send(:remove_const, :ZeitwerkDTIntegrationTestRoot)
      Object.send(:remove_const, :ZeitwerkDTIntegrationTestChild)
      Object.send(:remove_const, :ZeitwerkDTIntegrationTestGrandchild)
    end
  end
end
