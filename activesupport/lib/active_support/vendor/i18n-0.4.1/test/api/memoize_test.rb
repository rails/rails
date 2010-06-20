# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'
require 'api'

class I18nMemoizeBackendWithSimpleApiTest < Test::Unit::TestCase
  include Tests::Api::Basics
  include Tests::Api::Defaults
  include Tests::Api::Interpolation
  include Tests::Api::Link
  include Tests::Api::Lookup
  include Tests::Api::Pluralization
  include Tests::Api::Procs
  include Tests::Api::Localization::Date
  include Tests::Api::Localization::DateTime
  include Tests::Api::Localization::Time
  include Tests::Api::Localization::Procs
  
  class MemoizeBackend < I18n::Backend::Simple
    include I18n::Backend::Memoize
  end

  def setup
    I18n.backend = MemoizeBackend.new
    super
  end
  
  test "make sure we use the MemoizeBackend backend" do
    assert_equal MemoizeBackend, I18n.backend.class
  end
end

setup_rufus_tokyo

class I18nMemoizeBackendWithKeyValueApiTest < Test::Unit::TestCase
  include Tests::Api::Basics
  include Tests::Api::Defaults
  include Tests::Api::Interpolation
  include Tests::Api::Link
  include Tests::Api::Lookup
  include Tests::Api::Pluralization
  # include Tests::Api::Procs
  include Tests::Api::Localization::Date
  include Tests::Api::Localization::DateTime
  include Tests::Api::Localization::Time
  # include Tests::Api::Localization::Procs
  
  class MemoizeBackend < I18n::Backend::KeyValue
    include I18n::Backend::Memoize
  end

  STORE = Rufus::Tokyo::Cabinet.new('*')

  def setup
    I18n.backend = MemoizeBackend.new(STORE)
    super
  end
  
  test "make sure we use the MemoizeBackend backend" do
    assert_equal MemoizeBackend, I18n.backend.class
  end
end if defined?(Rufus::Tokyo::Cabinet)