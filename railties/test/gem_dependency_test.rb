require 'plugin_test_helper'

class Rails::GemDependency
  public :install_command, :unpack_command
end

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
      assert_equal ["unpack", "hpricot", "--version", '"= 0.6"'], @gem_with_version.unpack_command
    end

    def test_gem_adds_load_paths
      @gem.expects(:gem).with(@gem.name)
      @gem.add_load_paths
    end

    def test_gem_with_version_adds_load_paths
      @gem_with_version.expects(:gem).with(@gem_with_version.name, @gem_with_version.requirement.to_s)
      @gem_with_version.add_load_paths
    end

    def test_gem_loading
      @gem.expects(:gem).with(@gem.name)
      @gem.expects(:require).with(@gem.name)
      @gem.add_load_paths
      @gem.load
    end

    def test_gem_with_lib_loading
      @gem_with_lib.expects(:gem).with(@gem_with_lib.name)
      @gem_with_lib.expects(:require).with(@gem_with_lib.lib)
      @gem_with_lib.add_load_paths
      @gem_with_lib.load
    end

    def test_gem_without_lib_loading
      @gem_without_load.expects(:gem).with(@gem_without_load.name)
      @gem_without_load.expects(:require).with(@gem_without_load.lib).never
      @gem_without_load.add_load_paths
      @gem_without_load.load
    end

  end
end
