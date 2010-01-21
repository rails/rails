# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

class I18nBackendCascadeTest < Test::Unit::TestCase
  class Backend
    include I18n::Backend::Base
    include I18n::Backend::Cascade
  end

  def setup
    I18n.backend = Backend.new
    store_translations(:en,
      :foo => 'foo',
      :bar => { :baz => 'baz' }
    )
  end

  define_method "test: still returns an existing translation as usual" do
    assert_equal 'foo', I18n.t(:foo)
    assert_equal 'baz', I18n.t(:'bar.baz')
  end

  define_method "test: falls back by cutting keys off the end of the scope" do
    assert_equal 'foo', I18n.t(:'does_not_exist.foo')
    assert_equal 'foo', I18n.t(:'does_not_exist.does_not_exist.foo')

    assert_equal 'baz', I18n.t(:'bar.does_not_exist.baz')
    assert_equal 'baz', I18n.t(:'bar.does_not_exist.does_not_exist.baz')
  end

  define_method "test: raises I18n::MissingTranslationData exception when no translation was found" do
    assert_raises(I18n::MissingTranslationData) { I18n.t(:'foo.does_not_exist', :raise => true) }
    assert_raises(I18n::MissingTranslationData) { I18n.t(:'bar.baz.does_not_exist', :raise => true) }
    assert_raises(I18n::MissingTranslationData) { I18n.t(:'does_not_exist.bar.baz', :raise => true) }
  end

  define_method "test: cascades before evaluating the default" do
    assert_equal 'foo', I18n.t(:foo, :scope => :does_not_exist, :default => 'default')
  end

  define_method "test: let's us assemble required fallbacks for ActiveRecord validation messages" do
    store_translations(:en,
      :errors => {
        :reply => {
          :title => {
            :blank => 'blank on reply title'
          },
          :taken => 'taken on reply'
        },
        :topic => {
          :title => {
            :format => 'format on topic title'
          },
          :length => 'length on topic'
        },
        :odd => 'odd on errors'
      }
    )
    assert_equal 'blank on reply title',  I18n.t(:'errors.reply.title.blank',  :default => :'errors.topic.title.blank')
    assert_equal 'taken on reply',        I18n.t(:'errors.reply.title.taken',  :default => :'errors.topic.title.taken')
    assert_equal 'format on topic title', I18n.t(:'errors.reply.title.format', :default => :'errors.topic.title.format')
    assert_equal 'length on topic',       I18n.t(:'errors.reply.title.length', :default => :'errors.topic.title.length')
    assert_equal 'odd on errors',         I18n.t(:'errors.reply.title.odd',    :default => :'errors.topic.title.odd')
  end
end
