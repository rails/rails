# encoding: utf-8
require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

setup_active_record


class I18nActiveRecordApiTest < Test::Unit::TestCase
  def setup
    I18n.backend = I18n::Backend::ActiveRecord.new
    super
  end

  include Tests::Api::Basics
  include Tests::Api::Defaults
  include Tests::Api::Interpolation
  include Tests::Api::Link
  include Tests::Api::Lookup
  include Tests::Api::Pluralization
  include Tests::Api::Procs unless RUBY_VERSION >= '1.9.1'

  include Tests::Api::Localization::Date
  include Tests::Api::Localization::DateTime
  include Tests::Api::Localization::Time
  include Tests::Api::Localization::Procs unless RUBY_VERSION >= '1.9.1'

  define_method "test: make sure we use an ActiveRecord backend" do
    assert_equal I18n::Backend::ActiveRecord, I18n.backend.class
  end
end if defined?(ActiveRecord)
