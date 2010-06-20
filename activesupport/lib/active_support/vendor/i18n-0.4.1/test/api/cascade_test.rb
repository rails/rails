# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'
require 'api'

class I18nCascadeApiTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
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

  test "make sure we use a backend with Cascade included" do
    assert_equal Backend, I18n.backend.class
  end
end