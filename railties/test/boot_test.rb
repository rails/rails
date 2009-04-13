require 'abstract_unit'
require 'initializer'
require "#{File.dirname(__FILE__)}/../environments/boot"

class BootTest < Test::Unit::TestCase
  def test_boot_returns_if_booted
    Rails.expects(:booted?).returns(true)
    Rails.expects(:pick_boot).never
    assert_nil Rails.boot!
  end

  def test_boot_preinitializes_then_picks_and_runs_if_not_booted
    Rails.expects(:booted?).returns(false)
    Rails.expects(:preinitialize)
    Rails.expects(:pick_boot).returns(mock(:run => 'result'))
    assert_equal 'result', Rails.boot!
  end

  def test_preinitialize_does_not_raise_exception_if_preinitializer_file_does_not_exist
    Rails.stubs(:preinitializer_path).returns('/there/is/no/such/file')

    assert_nothing_raised { Rails.preinitialize }
  end

  def test_load_preinitializer_loads_preinitializer_file
    Rails.stubs(:preinitializer_path).returns("#{File.dirname(__FILE__)}/fixtures/environment_with_constant.rb")

    assert_nil $initialize_test_set_from_env
    Rails.preinitialize
    assert_equal "success", $initialize_test_set_from_env
  ensure
    $initialize_test_set_from_env = nil
  end

  def test_boot_vendor_rails_by_default
    Rails.expects(:booted?).returns(false)
    Rails.expects(:preinitialize)
    File.expects(:exist?).with("#{RAILS_ROOT}/vendor/rails").returns(true)
    Rails::VendorBoot.any_instance.expects(:run).returns('result')
    assert_equal 'result', Rails.boot!
  end

  def test_boot_gem_rails_otherwise
    Rails.expects(:booted?).returns(false)
    Rails.expects(:preinitialize)
    File.expects(:exist?).with("#{RAILS_ROOT}/vendor/rails").returns(false)
    Rails::GemBoot.any_instance.expects(:run).returns('result')
    assert_equal 'result', Rails.boot!
  end

  def test_run_loads_initializer_and_sets_load_path
    boot = Rails::Boot.new
    boot.expects(:load_initializer)
    Rails::Initializer.expects(:run).with(:set_load_path)
    boot.run
  end
end

class VendorBootTest < Test::Unit::TestCase
  include Rails

  def test_load_initializer_requires_from_vendor_rails
    boot = VendorBoot.new
    boot.expects(:require).with("#{RAILS_ROOT}/vendor/rails/railties/lib/initializer")
    Rails::Initializer.expects(:run).with(:install_gem_spec_stubs)
    Rails::GemDependency.expects(:add_frozen_gem_path)
    boot.load_initializer
  end
end

class GemBootTest < Test::Unit::TestCase
  include Rails

  def test_load_initializer_loads_rubygems_and_the_rails_gem
    boot = GemBoot.new
    GemBoot.expects(:load_rubygems)
    boot.expects(:load_rails_gem)
    boot.expects(:require).with('initializer')
    boot.load_initializer
  end

  def test_load_rubygems_exits_with_error_if_missing
    GemBoot.expects(:require).with('rubygems').raises(LoadError, 'missing rubygems')
    STDERR.expects(:puts)
    GemBoot.expects(:exit).with(1)
    GemBoot.load_rubygems
  end

  def test_load_rubygems_exits_with_error_if_too_old
    GemBoot.stubs(:rubygems_version).returns('0.0.1')
    GemBoot.expects(:require).with('rubygems').returns(true)
    STDERR.expects(:puts)
    GemBoot.expects(:exit).with(1)
    GemBoot.load_rubygems
  end

  def test_load_rails_gem_activates_specific_gem_if_version_given
    GemBoot.stubs(:gem_version).returns('0.0.1')

    boot = GemBoot.new
    boot.expects(:gem).with('rails', '0.0.1')
    boot.load_rails_gem
  end

  def test_load_rails_gem_activates_latest_gem_if_no_version_given
    GemBoot.stubs(:gem_version).returns(nil)

    boot = GemBoot.new
    boot.expects(:gem).with('rails')
    boot.load_rails_gem
  end

  def test_load_rails_gem_exits_with_error_if_missing
    GemBoot.stubs(:gem_version).returns('0.0.1')

    boot = GemBoot.new
    boot.expects(:gem).with('rails', '0.0.1').raises(Gem::LoadError, 'missing rails 0.0.1 gem')
    STDERR.expects(:puts)
    boot.expects(:exit).with(1)
    boot.load_rails_gem
  end
end

class ParseGemVersionTest < Test::Unit::TestCase
  def test_should_return_nil_if_no_lines_are_passed
    assert_equal nil, parse('')
    assert_equal nil, parse(nil)
  end

  def test_should_accept_either_single_or_double_quotes
    assert_equal "1.2.3", parse("RAILS_GEM_VERSION = '1.2.3'")
    assert_equal "1.2.3", parse('RAILS_GEM_VERSION = "1.2.3"')
  end

  def test_should_return_nil_if_no_lines_match
    assert_equal nil, parse('nothing matches on this line\nor on this line')
  end

  def test_should_parse_with_no_leading_space
    assert_equal "1.2.3", parse("RAILS_GEM_VERSION = '1.2.3' unless defined? RAILS_GEM_VERSION")
    assert_equal "1.2.3", parse("RAILS_GEM_VERSION = '1.2.3'")
  end

  def test_should_parse_with_any_number_of_leading_spaces
    assert_equal nil, parse([])
    assert_equal "1.2.3", parse(" RAILS_GEM_VERSION = '1.2.3' unless defined? RAILS_GEM_VERSION")
    assert_equal "1.2.3", parse("   RAILS_GEM_VERSION = '1.2.3' unless defined? RAILS_GEM_VERSION")
    assert_equal "1.2.3", parse(" RAILS_GEM_VERSION = '1.2.3'")
    assert_equal "1.2.3", parse("   RAILS_GEM_VERSION = '1.2.3'")
  end

  def test_should_ignore_unrelated_comments
    assert_equal "1.2.3", parse("# comment\nRAILS_GEM_VERSION = '1.2.3'\n# comment")
  end

  def test_should_ignore_commented_version_lines
    assert_equal "1.2.3", parse("#RAILS_GEM_VERSION = '9.8.7'\nRAILS_GEM_VERSION = '1.2.3'")
    assert_equal "1.2.3", parse("# RAILS_GEM_VERSION = '9.8.7'\nRAILS_GEM_VERSION = '1.2.3'")
    assert_equal "1.2.3", parse("RAILS_GEM_VERSION = '1.2.3'\n# RAILS_GEM_VERSION = '9.8.7'")
  end

  def test_should_allow_advanced_rubygems_version_specifications
    # See http://rubygems.org/read/chapter/16
    assert_equal "=1.2.3", parse("RAILS_GEM_VERSION = '=1.2.3'") # equal sign
    assert_equal "= 1.2.3", parse("RAILS_GEM_VERSION = '= 1.2.3'") # with space
    assert_equal "!=1.2.3", parse("RAILS_GEM_VERSION = '!=1.2.3'") # not equal
    assert_equal ">1.2.3", parse("RAILS_GEM_VERSION = '>1.2.3'") # greater than
    assert_equal "<1.2.3", parse("RAILS_GEM_VERSION = '<1.2.3'") # less than
    assert_equal ">=1.2.3", parse("RAILS_GEM_VERSION = '>=1.2.3'") # greater than or equal
    assert_equal "<=1.2.3", parse("RAILS_GEM_VERSION = '<=1.2.3'") # less than or equal
    assert_equal "~>1.2.3.0", parse("RAILS_GEM_VERSION = '~>1.2.3.0'") # approximately greater than
  end

  private
    def parse(text)
      Rails::GemBoot.parse_gem_version(text)
    end
end
