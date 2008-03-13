require 'plugin_test_helper'

class GeneratorLookupTest < Test::Unit::TestCase
  def setup
    @fixture_dirs = %w{alternate default}
    @configuration = Rails.configuration = Rails::Configuration.new
    # We need to add our testing plugin directory to the plugin paths so
    # the locator knows where to look for our plugins
    @configuration.plugin_paths += @fixture_dirs.map{|fd| plugin_fixture_path(fd)}
    @initializer = Rails::Initializer.new(@configuration)
    @initializer.add_plugin_load_paths
    @initializer.load_plugins
    load 'rails_generator.rb'
    require 'rails_generator/scripts'
  end

  def test_should_load_from_all_plugin_paths
    assert Rails::Generator::Base.lookup('a_generator')
    assert Rails::Generator::Base.lookup('stubby_generator')
  end
  
  def test_should_create_generator_source_for_each_directory_in_plugin_paths
    sources = Rails::Generator::Base.sources
    @fixture_dirs.each do |gen_dir|
      expected_label = "plugins (fixtures/plugins/#{gen_dir})".to_sym
      assert sources.any? {|source| source.label == expected_label }
    end
  end
  
  def test_should_preserve_order_in_usage_message
    msg = Rails::Generator::Scripts::Base.new.send(:usage_message)
    positions = @fixture_dirs.map do |gen_dir|
      pos = msg.index("Plugins (fixtures/plugins/#{gen_dir})")
      assert_not_nil pos
      pos
    end
    assert_equal positions.sort, positions
  end

end
