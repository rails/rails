# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'
require 'api'

setup_rufus_tokyo

class I18nKeyValueApiTest < Test::Unit::TestCase
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

  STORE = Rufus::Tokyo::Cabinet.new('*')

  def setup
    I18n.backend = I18n::Backend::KeyValue.new(STORE)
    super
  end

  test "make sure we use the KeyValue backend" do
    assert_equal I18n::Backend::KeyValue, I18n.backend.class
  end
end if defined?(Rufus::Tokyo::Cabinet)