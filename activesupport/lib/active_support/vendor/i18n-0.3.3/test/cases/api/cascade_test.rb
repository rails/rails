# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nCascadeApiTest < Test::Unit::TestCase
  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Cascade
  end

  def setup
    I18n.backend = Backend.new
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

  define_method "test: make sure we use a backend with Cascade included" do
    assert_equal Backend, I18n.backend.class
  end
end