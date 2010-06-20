# encoding: utf-8
$:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
require 'test_helper'

class I18nBackendCascadeTest < Test::Unit::TestCase
  class Backend < I18n::Backend::Simple
    include I18n::Backend::Cascade
  end

  def setup
    I18n.backend = Backend.new
    store_translations(:en,
      :foo => 'foo',
      :bar => { :baz => 'baz' }
    )
  end

  def lookup(key, options = {})
    I18n.t(key, options.merge(:cascade => { :step => 1, :offset => 1, :skip_root => false }))
  end

  test "still returns an existing translation as usual" do
    assert_equal 'foo', lookup(:foo)
    assert_equal 'baz', lookup(:'bar.baz')
  end

  test "falls back by cutting keys off the end of the scope" do
    assert_equal 'foo', lookup(:foo, :scope => :'missing')
    assert_equal 'foo', lookup(:foo, :scope => :'missing.missing')
    assert_equal 'baz', lookup(:baz, :scope => :'bar.missing')
    assert_equal 'baz', lookup(:baz, :scope => :'bar.missing.missing')
  end

  test "raises I18n::MissingTranslationData exception when no translation was found" do
    assert_raise(I18n::MissingTranslationData) { lookup(:'foo.missing', :raise => true) }
    assert_raise(I18n::MissingTranslationData) { lookup(:'bar.baz.missing', :raise => true) }
    assert_raise(I18n::MissingTranslationData) { lookup(:'missing.bar.baz', :raise => true) }
  end

  test "cascades before evaluating the default" do
    assert_equal 'foo', lookup(:foo, :scope => :missing, :default => 'default')
  end
  
  test "cascades defaults, too" do
    assert_equal 'foo', lookup(nil, :default => [:'missing.missing', :'missing.foo'])
  end

  test "let's us assemble required fallbacks for ActiveRecord validation messages" do
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
    assert_equal 'blank on reply title',  lookup(:'errors.reply.title.blank',  :default => :'errors.topic.title.blank')
    assert_equal 'taken on reply',        lookup(:'errors.reply.title.taken',  :default => :'errors.topic.title.taken')
    assert_equal 'format on topic title', lookup(:'errors.reply.title.format', :default => :'errors.topic.title.format')
    assert_equal 'length on topic',       lookup(:'errors.reply.title.length', :default => :'errors.topic.title.length')
    assert_equal 'odd on errors',         lookup(:'errors.reply.title.odd',    :default => :'errors.topic.title.odd')
  end
end
