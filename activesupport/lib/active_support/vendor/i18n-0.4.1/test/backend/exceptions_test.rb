# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'

class I18nBackendExceptionsTest < Test::Unit::TestCase
  def setup
    I18n.backend = I18n::Backend::Simple.new
  end

  test "exceptions: MissingTranslationData message from #translate includes the given scope and full key" do
    begin
      I18n.t(:'baz.missing', :scope => :'foo.bar', :raise => true)
    rescue I18n::MissingTranslationData => exception
    end
    assert_equal "translation missing: en, foo, bar, baz, missing", exception.message
  end

  test "exceptions: MissingTranslationData message from #localize includes the given scope and full key" do
    begin
      I18n.l(Time.now, :format => :foo)
    rescue I18n::MissingTranslationData => exception
    end
    assert_equal "translation missing: en, time, formats, foo", exception.message
  end
end