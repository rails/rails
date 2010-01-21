# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nFastBackendApiTest < Test::Unit::TestCase
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
  
  class FastBackend
    include I18n::Backend::Base
    include I18n::Backend::Fast
  end

  def setup
    I18n.backend = FastBackend.new
    super
  end
  
  define_method "test: make sure we use the FastBackend backend" do
    assert_equal FastBackend, I18n.backend.class
  end
end