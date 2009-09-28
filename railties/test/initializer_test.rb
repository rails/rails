require 'abstract_unit'
require 'initializer'

require 'action_view'
require 'action_mailer'
require 'active_record'

# Mocks out the configuration
module Rails
  def self.configuration
    Rails::Configuration.new
  end
end

class ConfigurationMock < Rails::Configuration
  attr_reader :environment_path

  def initialize(envpath)
    super()
    @environment_path = envpath
  end
end

class Initializer_load_environment_Test < Test::Unit::TestCase
  def test_load_environment_with_constant
    config = ConfigurationMock.new("#{File.dirname(__FILE__)}/fixtures/environment_with_constant.rb")
    assert_nil $initialize_test_set_from_env
    Rails::Initializer.run(:load_environment, config)
    assert_equal "success", $initialize_test_set_from_env
  ensure
    $initialize_test_set_from_env = nil
  end
end

class Initializer_eager_loading_Test < Test::Unit::TestCase
  def setup
    @config = ConfigurationMock.new("")
    @config.cache_classes = true
    @config.load_paths = [File.expand_path(File.dirname(__FILE__) + "/fixtures/eager")]
    @config.eager_load_paths = [File.expand_path(File.dirname(__FILE__) + "/fixtures/eager")]
    @initializer = Rails::Initializer.new(@config)
    @initializer.set_load_path
    @initializer.set_autoload_paths
  end

  def test_eager_loading_loads_parent_classes_before_children
    assert_nothing_raised do
      @initializer.load_application_classes
    end
  end
end

class Initializer_after_initialize_with_blocks_environment_Test < Test::Unit::TestCase
  def setup
    config = ConfigurationMock.new("")
    config.after_initialize do
      $test_after_initialize_block1 = "success"
    end
    config.after_initialize do
      $test_after_initialize_block2 = "congratulations"
    end
    assert_nil $test_after_initialize_block1
    assert_nil $test_after_initialize_block2

    Rails::Initializer.any_instance.expects(:gems_dependencies_loaded).returns(true)
    Rails::Initializer.run(:after_initialize, config)
  end

  def teardown
    $test_after_initialize_block1 = nil
    $test_after_initialize_block2 = nil
  end

  def test_should_have_called_the_first_after_initialize_block
    assert_equal "success", $test_after_initialize_block1
  end

  def test_should_have_called_the_second_after_initialize_block
    assert_equal "congratulations", $test_after_initialize_block2
  end
end

class Initializer_after_initialize_with_no_block_environment_Test < Test::Unit::TestCase
  def setup
    config = ConfigurationMock.new("")
    config.after_initialize do
      $test_after_initialize_block1 = "success"
    end
    config.after_initialize # don't pass a block, this is what we're testing!
    config.after_initialize do
      $test_after_initialize_block2 = "congratulations"
    end
    assert_nil $test_after_initialize_block1

    Rails::Initializer.any_instance.expects(:gems_dependencies_loaded).returns(true)
    Rails::Initializer.run(:after_initialize, config)
  end

  def teardown
    $test_after_initialize_block1 = nil
    $test_after_initialize_block2 = nil
  end

  def test_should_have_called_the_first_after_initialize_block
    assert_equal "success", $test_after_initialize_block1, "should still get set"
  end

  def test_should_have_called_the_second_after_initialize_block
    assert_equal "congratulations", $test_after_initialize_block2
  end
end

class ConfigurationFrameworkPathsTests < Test::Unit::TestCase
  def setup
    @config = Rails::Configuration.new
    @config.frameworks.clear

    File.stubs(:directory?).returns(true)
    @config.stubs(:framework_root_path).returns('')
  end

  def test_minimal
    expected = %w(
      /railties
      /railties/lib
      /activesupport/lib
    )
    assert_equal expected, @config.framework_paths
  end

  def test_actioncontroller_or_actionview_add_actionpack
    @config.frameworks << :action_controller
    assert_framework_path '/actionpack/lib'

    @config.frameworks = [:action_view]
    assert_framework_path '/actionpack/lib'
  end

  def test_paths_for_ar_ares_and_mailer
    [:active_record, :action_mailer, :active_resource, :action_web_service].each do |framework|
      @config.frameworks = [framework]
      assert_framework_path "/#{framework.to_s.gsub('_', '')}/lib"
    end
  end

  def test_unknown_framework_raises_error
    @config.frameworks << :action_foo
    initializer = Rails::Initializer.new @config
    initializer.expects(:require).raises(LoadError)

    assert_raise RuntimeError do
      initializer.send :require_frameworks
    end
  end

  def test_action_mailer_load_paths_set_only_if_action_mailer_in_use
    @config.frameworks = [:action_controller]
    initializer = Rails::Initializer.new @config
    initializer.send :require_frameworks

    assert_nothing_raised NameError do
      initializer.send :load_view_paths
    end
  end

  def test_action_controller_load_paths_set_only_if_action_controller_in_use
    @config.frameworks = []
    initializer = Rails::Initializer.new @config
    initializer.send :require_frameworks

    assert_nothing_raised NameError do
      initializer.send :load_view_paths
    end
  end

  protected
    def assert_framework_path(path)
      assert @config.framework_paths.include?(path),
        "<#{path.inspect}> not found among <#{@config.framework_paths.inspect}>"
    end
end

require File.dirname(__FILE__) + '/plugin_test_helper'

class InitializerPluginLoadingTests < Test::Unit::TestCase
  def setup
    @configuration     = Rails::Configuration.new
    @configuration.frameworks -= [:action_mailer]
    @configuration.plugin_paths << plugin_fixture_root_path
    @initializer       = Rails::Initializer.new(@configuration)
    @valid_plugin_path = plugin_fixture_path('default/stubby')
    @empty_plugin_path = plugin_fixture_path('default/empty')
  end

  def test_no_plugins_are_loaded_if_the_configuration_has_an_empty_plugin_list
    only_load_the_following_plugins! []
    @initializer.load_plugins
    assert_equal [], @initializer.loaded_plugins
  end

  def test_only_the_specified_plugins_are_located_in_the_order_listed
    plugin_names = [:plugin_with_no_lib_dir, :acts_as_chunky_bacon]
    only_load_the_following_plugins! plugin_names
    load_plugins!
    assert_plugins plugin_names, @initializer.loaded_plugins
  end

  def test_all_plugins_are_loaded_when_registered_plugin_list_is_untouched
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    load_plugins!
    assert_plugins [:a, :acts_as_chunky_bacon, :engine, :gemlike, :plugin_with_no_lib_dir, :stubby], @initializer.loaded_plugins, failure_tip
  end

  def test_all_plugins_loaded_when_all_is_used
    plugin_names = [:stubby, :acts_as_chunky_bacon, :all]
    only_load_the_following_plugins! plugin_names
    load_plugins!
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_plugins [:stubby, :acts_as_chunky_bacon, :a, :engine, :gemlike, :plugin_with_no_lib_dir], @initializer.loaded_plugins, failure_tip
  end

  def test_all_plugins_loaded_after_all
    plugin_names = [:stubby, :all, :acts_as_chunky_bacon]
    only_load_the_following_plugins! plugin_names
    load_plugins!
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_plugins [:stubby, :a, :engine, :gemlike, :plugin_with_no_lib_dir, :acts_as_chunky_bacon], @initializer.loaded_plugins, failure_tip
  end

  def test_plugin_names_may_be_strings
    plugin_names = ['stubby', 'acts_as_chunky_bacon', :a, :plugin_with_no_lib_dir]
    only_load_the_following_plugins! plugin_names
    load_plugins!
    failure_tip = "It's likely someone has added a new plugin fixture without updating this list"
    assert_plugins plugin_names, @initializer.loaded_plugins, failure_tip
  end

  def test_registering_a_plugin_name_that_does_not_exist_raises_a_load_error
    only_load_the_following_plugins! [:stubby, :acts_as_a_non_existant_plugin]
    assert_raise(LoadError) do
      load_plugins!
    end
  end

  def test_load_error_messages_mention_missing_plugins_and_no_others
    valid_plugin_names = [:stubby, :acts_as_chunky_bacon]
    invalid_plugin_names = [:non_existant_plugin1, :non_existant_plugin2]
    only_load_the_following_plugins!( valid_plugin_names + invalid_plugin_names )
    begin
      load_plugins!
      flunk "Expected a LoadError but did not get one"
    rescue LoadError => e
      failure_tip = "It's likely someone renamed or deleted plugin fixtures without updating this test"
      assert_plugins valid_plugin_names, @initializer.loaded_plugins, failure_tip
      invalid_plugin_names.each do |plugin|
        assert_match(/#{plugin.to_s}/, e.message, "LoadError message should mention plugin '#{plugin}'")
      end
      valid_plugin_names.each do |plugin|
        assert_no_match(/#{plugin.to_s}/, e.message, "LoadError message should not mention '#{plugin}'")
      end

    end
  end

  def test_should_ensure_all_loaded_plugins_load_paths_are_added_to_the_load_path
    only_load_the_following_plugins! [:stubby, :acts_as_chunky_bacon]

    @initializer.add_plugin_load_paths

    assert $LOAD_PATH.include?(File.join(plugin_fixture_path('default/stubby'), 'lib'))
    assert $LOAD_PATH.include?(File.join(plugin_fixture_path('default/acts/acts_as_chunky_bacon'), 'lib'))
  end

  private

    def load_plugins!
      @initializer.add_plugin_load_paths
      @initializer.load_plugins
    end
end

class InitializerSetupI18nTests < Test::Unit::TestCase
  def test_no_config_locales_dir_present_should_return_empty_load_path
    File.stubs(:exist?).returns(false)
    assert_equal [], Rails::Configuration.new.i18n.load_path
  end

  def test_config_locales_dir_present_should_be_added_to_load_path
    File.stubs(:exist?).returns(true)
    Dir.stubs(:[]).returns([ "my/test/locale.yml" ])
    assert_equal [ "my/test/locale.yml" ], Rails::Configuration.new.i18n.load_path
  end

  def test_config_defaults_should_be_added_with_config_settings
    File.stubs(:exist?).returns(true)
    Dir.stubs(:[]).returns([ "my/test/locale.yml" ])

    config = Rails::Configuration.new
    config.i18n.load_path << "my/other/locale.yml"

    assert_equal [ "my/test/locale.yml", "my/other/locale.yml" ], config.i18n.load_path
  end

  def test_config_defaults_and_settings_should_be_added_to_i18n_defaults
    File.stubs(:exist?).returns(true)
    Dir.stubs(:[]).returns([ "my/test/locale.yml" ])

    config = Rails::Configuration.new
    config.i18n.load_path << "my/other/locale.yml"

    Rails::Initializer.run(:initialize_i18n, config)
    assert_equal [
     File.expand_path(File.dirname(__FILE__) + "/../../activesupport/lib/active_support/locale/en.yml"),
     File.expand_path(File.dirname(__FILE__) + "/../../actionpack/lib/action_view/locale/en.yml"),
     File.expand_path(File.dirname(__FILE__) + "/../../activerecord/lib/active_record/locale/en.yml"),
     # FIXME: should clean I18n.load_path between each test
     File.expand_path(File.dirname(__FILE__) + "/../../railties/test/fixtures/plugins/engines/engine/config/locales/en.yml"),
     "my/test/locale.yml",
     "my/other/locale.yml" ], I18n.load_path.collect { |path| path =~ /^\./ ? File.expand_path(path) : path }
  end

  def test_setting_another_default_locale
    config = Rails::Configuration.new
    config.i18n.default_locale = :de
    Rails::Initializer.run(:initialize_i18n, config)
    assert_equal :de, I18n.default_locale
  end
end

class InitializerDatabaseMiddlewareTest < Test::Unit::TestCase
  def setup
    @config = Rails::Configuration.new
    @config.frameworks = [:active_record, :action_controller, :action_view]
  end

  def test_initialize_database_middleware_doesnt_perform_anything_when_active_record_not_in_frameworks
    @config.frameworks.clear
    @config.expects(:middleware).never
    Rails::Initializer.run(:initialize_database_middleware, @config)
  end

  def test_database_middleware_initializes_when_session_store_is_active_record
    store = ActionController::Base.session_store
    ActionController::Base.session_store = ActiveRecord::SessionStore

    @config.middleware.expects(:insert_before).with(:"ActiveRecord::SessionStore", ActiveRecord::ConnectionAdapters::ConnectionManagement)
    @config.middleware.expects(:insert_before).with(:"ActiveRecord::SessionStore", ActiveRecord::QueryCache)

    Rails::Initializer.run(:initialize_database_middleware, @config)
  ensure
    ActionController::Base.session_store = store
  end

  def test_database_middleware_doesnt_initialize_when_session_store_is_not_active_record
    store = ActionController::Base.session_store
    ActionController::Base.session_store = ActionController::Session::CookieStore

    # Define the class, so we don't have to actually make it load
    eval("class ActiveRecord::ConnectionAdapters::ConnectionManagement; end")

    @config.middleware.expects(:use).with(ActiveRecord::ConnectionAdapters::ConnectionManagement)
    @config.middleware.expects(:use).with(ActiveRecord::QueryCache)

    Rails::Initializer.run(:initialize_database_middleware, @config)
  ensure
    ActionController::Base.session_store = store
  end

  def test_ensure_database_middleware_doesnt_use_action_controller_on_initializing
    @config.frameworks -= [:action_controller]
    store = ActionController::Base.session_store
    ActionController::Base.session_store = ActiveRecord::SessionStore

    @config.middleware.expects(:use).with(ActiveRecord::ConnectionAdapters::ConnectionManagement)
    @config.middleware.expects(:use).with(ActiveRecord::QueryCache)

    Rails::Initializer.run(:initialize_database_middleware, @config)
  ensure
    ActionController::Base.session_store = store
    @config.frameworks += [:action_controller]
  end
end

class InitializerViewPathsTest  < Test::Unit::TestCase
  def setup
    @config = Rails::Configuration.new
    @config.frameworks = [:action_view, :action_controller, :action_mailer]

    ActionController::Base.stubs(:view_paths).returns(stub)
    ActionMailer::Base.stubs(:view_paths).returns(stub)
  end

  def test_load_view_paths_doesnt_perform_anything_when_action_view_not_in_frameworks
    @config.frameworks -= [:action_view]
    ActionController::Base.view_paths.expects(:load!).never
    ActionMailer::Base.view_paths.expects(:load!).never
    Rails::Initializer.run(:load_view_paths, @config)
  end
  
  def test_load_view_paths_loads_view_paths
    ActionController::Base.view_paths.expects(:load!)
    ActionMailer::Base.view_paths.expects(:load!)
    Rails::Initializer.run(:load_view_paths, @config)
  end
end

class RailsRootTest < Test::Unit::TestCase
  def test_rails_dot_root_equals_rails_root
    assert_equal RAILS_ROOT, Rails.root.to_s
  end

  def test_rails_dot_root_should_be_a_pathname
    assert_equal File.join(RAILS_ROOT, 'app', 'controllers'), Rails.root.join('app', 'controllers').to_s
  end
end

