# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nApiChainTest < Test::Unit::TestCase
  def setup
    super
    I18n.backend = I18n::Backend::Chain.new(I18n::Backend::Simple.new, I18n.backend)
  end

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

  define_method "test: make sure we use the Chain backend" do
    assert_equal I18n::Backend::Chain, I18n.backend.class
  end
end