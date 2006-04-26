require 'test/unit'

unless defined? ActiveSupport::OptionMerger
  require File.dirname(__FILE__) + '/../lib/active_support/option_merger'
  require File.dirname(__FILE__) + '/../lib/active_support/core_ext/object'
end

class OptionMergerTest < Test::Unit::TestCase
  def setup
    @options = {:hello => 'world'}
  end
  
  def test_method_with_options_merges_options_when_options_are_present
    local_options = {:cool => true}
    
    with_options(@options) do |o|
      assert_equal local_options, method_with_options(local_options)
      assert_equal @options.merge(local_options), 
        o.method_with_options(local_options)
    end
  end
  
  def test_method_with_options_appends_options_when_options_are_missing
    with_options(@options) do |o|
      assert_equal Hash.new, method_with_options
      assert_equal @options, o.method_with_options
    end
  end

  def test_method_with_options_allows_to_overwrite_options
    local_options = {:hello => 'moon'}
    assert_equal @options.keys, local_options.keys
    
    with_options(@options) do |o|
      assert_equal local_options, method_with_options(local_options)
      assert_equal @options.merge(local_options), 
        o.method_with_options(local_options)
      assert_equal local_options, o.method_with_options(local_options)
    end
    with_options(local_options) do |o|
      assert_equal local_options.merge(@options),
        o.method_with_options(@options)
    end
  end

  private
    def method_with_options(options = {})
      options
    end
end
