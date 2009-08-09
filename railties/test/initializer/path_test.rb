require "initializer/test_helper"

class PathsTest < Test::Unit::TestCase
  include ActiveSupport::Testing::Isolation

  def self.setup
    Rails::Initializer.run do |config|
      config.frameworks = [:action_controller, :action_view, :action_mailer, :active_record]
    end
  end

  def setup
    @paths = Rails::Initializer.default.config.paths
  end

  def root(*path)
    File.expand_path(File.join(File.dirname(__FILE__), "root", *path))
  end

  def assert_path(paths, *dir)
    assert_equal [root(*dir)], paths.paths
  end

  test "booting up Rails yields a valid paths object" do
    assert_path @paths.app, "app"
    assert_path @paths.app.metals, "app", "metal"
    assert_path @paths.app.models, "app", "models"
    assert_path @paths.app.helpers, "app", "helpers"
    assert_path @paths.app.services, "app", "services"
    assert_path @paths.lib, "lib"
    assert_path @paths.vendor, "vendor"
    assert_path @paths.vendor.plugins, "vendor", "plugins"
    assert_path @paths.tmp, "tmp"
    assert_path @paths.tmp.cache, "tmp", "cache"
    assert_path @paths.config, "config"
    assert_path @paths.config.locales, "config", "locales"
    assert_path @paths.config.environments, "config", "environments"

    assert_equal Pathname.new(File.dirname(__FILE__)).join("root", "app", "controllers").expand_path,
      Pathname.new(@paths.app.controllers.to_a.first).expand_path
    assert_equal Pathname.new(File.dirname(__FILE__)).join("..", "..", "builtin", "rails_info").expand_path,
      Pathname.new(@paths.app.controllers.to_a[1]).expand_path
  end

  test "booting up Rails yields a list of paths that are eager" do
    assert @paths.app.models.eager_load?
    assert @paths.app.controllers.eager_load?
    assert @paths.app.helpers.eager_load?
    assert @paths.app.metals.eager_load?
  end

  test "environments has a glob equal to the current environment" do
    assert_equal "#{RAILS_ENV}.rb", @paths.config.environments.glob
  end

  def assert_in_load_path(*path)
    assert $:.any? { |p| File.expand_path(p) == root(*path) }, "Load path does not include '#{root(*path)}'. They are:\n-----\n #{$:.join("\n")}\n-----"
  end

  def assert_not_in_load_path(*path)
    assert !$:.any? { |p| File.expand_path(p) == root(*path) }, "Load path includes '#{root(*path)}'. They are:\n-----\n #{$:.join("\n")}\n-----"
  end

  test "load path includes each of the paths in config.paths as long as the directories exist" do
    assert_in_load_path "app"
    assert_in_load_path "app", "controllers"
    assert_in_load_path "app", "metal"
    assert_in_load_path "app", "models"
    assert_in_load_path "app", "helpers"
    assert_in_load_path "lib"
    assert_in_load_path "vendor"

    assert_not_in_load_path "app", "views"
    assert_not_in_load_path "app", "services"
    assert_not_in_load_path "config"
    assert_not_in_load_path "config", "locales"
    assert_not_in_load_path "config", "environments"
    assert_not_in_load_path "tmp"
    assert_not_in_load_path "tmp", "cache"
  end

  test "controller paths include builtin in development mode" do
    RAILS_ENV.replace "development"
    assert Rails::Configuration.new.paths.app.controllers.paths.any? { |p| p =~ /builtin/ }
  end

  test "controller paths does not have builtin_directories in test mode" do
    RAILS_ENV.replace "test"
    assert !Rails::Configuration.new.paths.app.controllers.paths.any? { |p| p =~ /builtin/ }
  end

  test "controller paths does not have builtin_directories in production mode" do
    RAILS_ENV.replace "production"
    assert !Rails::Configuration.new.paths.app.controllers.paths.any? { |p| p =~ /builtin/ }
  end

end