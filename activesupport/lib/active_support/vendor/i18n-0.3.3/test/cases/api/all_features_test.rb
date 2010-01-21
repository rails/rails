# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nAllFeaturesApiTest < Test::Unit::TestCase
  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Cache
    include I18n::Backend::Metadata
    include I18n::Backend::Cascade
    include I18n::Backend::Fallbacks
    include I18n::Backend::Pluralization
    include I18n::Backend::Fast
    include I18n::Backend::InterpolationCompiler
  end

  def setup
    I18n.backend = I18n::Backend::Chain.new(Backend.new, I18n::Backend::Simple.new)
    super
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

  define_method "test: make sure we use a Chain backend with an all features backend" do
    assert_equal I18n::Backend::Chain, I18n.backend.class
    assert_equal Backend, I18n.backend.backends.first.class
  end
  
  # links: test that keys stored on one backend can link to keys stored on another backend
end