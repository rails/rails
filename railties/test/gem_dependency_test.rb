require 'plugin_test_helper'

class Rails::GemDependency
  public :install_command, :unpack_command
end

Rails::VendorGemSourceIndex.silence_spec_warnings = true

uses_mocha "Plugin Tests" do
  class GemDependencyTest < Test::Unit::TestCase
    def setup
      @gem              = Rails::GemDependency.new "hpricot"
      @gem_with_source  = Rails::GemDependency.new "hpricot", :source => "http://code.whytheluckystiff.net"
      @gem_with_version = Rails::GemDependency.new "hpricot", :version => "= 0.6"
      @gem_with_lib     = Rails::GemDependency.new "aws-s3", :lib => "aws/s3"
      @gem_without_load  = Rails::GemDependency.new "hpricot", :lib => false
    end

    def test_configuration_adds_gem_dependency
      config = Rails::Configuration.new
      config.gem "aws-s3", :lib => "aws/s3", :version => "0.4.0"
      assert_equal [["install", "aws-s3", "--version", '"= 0.4.0"']], config.gems.collect(&:install_command)
    end

    def test_gem_creates_install_command
      assert_equal %w(install hpricot), @gem.install_command
    end

    def test_gem_with_source_creates_install_command
      assert_equal %w(install hpricot --source http://code.whytheluckystiff.net), @gem_with_source.install_command
    end

    def test_gem_with_version_creates_install_command
      assert_equal ["install", "hpricot", "--version", '"= 0.6"'], @gem_with_version.install_command
    end

    def test_gem_creates_unpack_command
      assert_equal %w(unpack hpricot), @gem.unpack_command
    end

    def test_gem_with_version_unpack_install_command
      # stub out specification method, or else test will fail if hpricot 0.6 isn't installed
      mock_spec = mock()
      mock_spec.stubs(:version).returns('0.6')
      @gem_with_version.stubs(:specification).returns(mock_spec)
      assert_equal ["unpack", "hpricot", "--version", '= 0.6'], @gem_with_version.unpack_command
    end

    def test_gem_adds_load_paths
      @gem.expects(:gem).with(Gem::Dependency.new(@gem.name, nil))
      @gem.add_load_paths
    end

    def test_gem_with_version_adds_load_paths
      @gem_with_version.expects(:gem).with(Gem::Dependency.new(@gem_with_version.name, @gem_with_version.requirement.to_s))
      @gem_with_version.add_load_paths
    end

    def test_gem_loading
      @gem.expects(:gem).with(Gem::Dependency.new(@gem.name, nil))
      @gem.expects(:require).with(@gem.name)
      @gem.add_load_paths
      @gem.load
    end

    def test_gem_with_lib_loading
      @gem_with_lib.expects(:gem).with(Gem::Dependency.new(@gem_with_lib.name, nil))
      @gem_with_lib.expects(:require).with(@gem_with_lib.lib)
      @gem_with_lib.add_load_paths
      @gem_with_lib.load
    end

    def test_gem_without_lib_loading
      @gem_without_load.expects(:gem).with(Gem::Dependency.new(@gem_without_load.name, nil))
      @gem_without_load.expects(:require).with(@gem_without_load.lib).never
      @gem_without_load.add_load_paths
      @gem_without_load.load
    end

    def test_gem_dependencies_compare_for_uniq
      gem1 = Rails::GemDependency.new "gem1"
      gem1a = Rails::GemDependency.new "gem1"
      gem2 = Rails::GemDependency.new "gem2"
      gem2a = Rails::GemDependency.new "gem2"
      gem3 = Rails::GemDependency.new "gem2", :version => ">=0.1"
      gem3a = Rails::GemDependency.new "gem2", :version => ">=0.1"
      gem4 = Rails::GemDependency.new "gem3"
      gems = [gem1, gem2, gem1a, gem3, gem2a, gem4, gem3a, gem2, gem4]
      assert_equal 4, gems.uniq.size
    end

    def test_gem_load_frozen
      dummy_gem = Rails::GemDependency.new "dummy-gem-a"
      dummy_gem.add_load_paths
      dummy_gem.load
      assert_not_nil DUMMY_GEM_A_VERSION
    end

    def test_gem_load_frozen_specific_version
      dummy_gem = Rails::GemDependency.new "dummy-gem-b", :version => '0.4.0'
      dummy_gem.add_load_paths
      dummy_gem.load
      assert_not_nil DUMMY_GEM_B_VERSION
      assert_equal '0.4.0', DUMMY_GEM_B_VERSION
    end

    def test_gem_load_frozen_minimum_version
      dummy_gem = Rails::GemDependency.new "dummy-gem-c", :version => '>=0.5.0'
      dummy_gem.add_load_paths
      dummy_gem.load
      assert_not_nil DUMMY_GEM_C_VERSION
      assert_equal '0.6.0', DUMMY_GEM_C_VERSION
    end

    def test_gem_load_missing_specification
      dummy_gem = Rails::GemDependency.new "dummy-gem-d"
      dummy_gem.add_load_paths
      dummy_gem.load
      assert_not_nil DUMMY_GEM_D_VERSION
      assert_equal '1.0.0', DUMMY_GEM_D_VERSION
      assert_equal ['lib', 'lib/dummy-gem-d.rb'], dummy_gem.specification.files
    end

    def test_gem_load_bad_specification
      dummy_gem = Rails::GemDependency.new "dummy-gem-e", :version => "= 1.0.0"
      dummy_gem.add_load_paths
      dummy_gem.load
      assert_not_nil DUMMY_GEM_E_VERSION
      assert_equal '1.0.0', DUMMY_GEM_E_VERSION
    end

  end
end
