require "isolation/abstract_unit"

module ApplicationTests
  class PathsTest < ActiveSupport::TestCase
    include ActiveSupport::Testing::Isolation

    def setup
      build_app
      FileUtils.rm_rf("#{app_path}/config/environments")
      app_file "config/environments/development.rb", ""
      add_to_config <<-RUBY
        config.root = "#{app_path}"
        config.after_initialize do |app|
          app.config.session_store nil
        end
      RUBY
      require "#{app_path}/config/environment"
      @paths = Rails.application.config.paths
    end

    def teardown
      teardown_app
    end

    def root(*path)
      app_path(*path).to_s
    end

    def assert_path(paths, *dir)
      assert_equal [root(*dir)], paths.expanded
    end

    def assert_in_load_path(*path)
      assert $:.any? { |p| File.expand_path(p) == root(*path) }, "Load path does not include '#{root(*path)}'. They are:\n-----\n #{$:.join("\n")}\n-----"
    end

    def assert_not_in_load_path(*path)
      assert !$:.any? { |p| File.expand_path(p) == root(*path) }, "Load path includes '#{root(*path)}'. They are:\n-----\n #{$:.join("\n")}\n-----"
    end

    test "booting up Rails yields a valid paths object" do
      assert_path @paths["app/models"],          "app/models"
      assert_path @paths["app/helpers"],         "app/helpers"
      assert_path @paths["app/views"],           "app/views"
      assert_path @paths["lib"],                 "lib"
      assert_path @paths["vendor"],              "vendor"
      assert_path @paths["tmp"],                 "tmp"
      assert_path @paths["config"],              "config"
      assert_path @paths["config/locales"],      "config/locales/en.yml"
      assert_path @paths["config/environment"],  "config/environment.rb"
      assert_path @paths["config/environments"], "config/environments/development.rb"

      assert_equal root("app", "controllers"), @paths["app/controllers"].expanded.first
    end

    test "booting up Rails yields a list of paths that are eager" do
      eager_load = @paths.eager_load
      assert eager_load.include?(root("app/controllers"))
      assert eager_load.include?(root("app/helpers"))
      assert eager_load.include?(root("app/models"))
    end

    test "environments has a glob equal to the current environment" do
      assert_equal "#{Rails.env}.rb", @paths["config/environments"].glob
    end

    test "load path includes each of the paths in config.paths as long as the directories exist" do
      assert_in_load_path "app", "controllers"
      assert_in_load_path "app", "models"
      assert_in_load_path "app", "helpers"
      assert_in_load_path "lib"
      assert_in_load_path "vendor"

      assert_not_in_load_path "app", "views"
      assert_not_in_load_path "config"
      assert_not_in_load_path "config", "locales"
      assert_not_in_load_path "config", "environments"
      assert_not_in_load_path "tmp"
      assert_not_in_load_path "tmp", "cache"
    end
  end
end
