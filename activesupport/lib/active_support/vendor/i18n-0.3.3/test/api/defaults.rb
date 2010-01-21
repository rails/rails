# encoding: utf-8

module Tests
  module Api
    module Defaults
      def setup
        super
        store_translations(:foo => { :bar => 'bar', :baz => 'baz' })
      end
      
      define_method "test defaults: given nil as a key it returns the given default" do
        assert_equal 'default', I18n.t(nil, :default => 'default')
      end
      
      define_method "test defaults: given a symbol as a default it translates the symbol" do
        assert_equal 'bar', I18n.t(nil, :default => :'foo.bar')
      end

      define_method "test defaults: given a symbol as a default and a scope it stays inside the scope when looking up the symbol" do
        assert_equal 'bar', I18n.t(:missing, :default => :bar, :scope => :foo)
      end

      define_method "test defaults: given an array as a default it returns the first match" do
        assert_equal 'bar', I18n.t(:does_not_exist, :default => [:does_not_exist_2, :'foo.bar'])
      end

      define_method "test defaults: given an array of missing keys it raises a MissingTranslationData exception" do
        assert_raises I18n::MissingTranslationData do
          I18n.t(:does_not_exist, :default => [:does_not_exist_2, :does_not_exist_3], :raise => true)
        end
      end

      define_method "test defaults: using a custom scope separator" do
        # data must have been stored using the custom separator when using the ActiveRecord backend
        I18n.backend.store_translations(:en, { :foo => { :bar => 'bar' } }, { :separator => '|' })
        assert_equal 'bar', I18n.t(nil, :default => :'foo|bar', :separator => '|')
      end
    end
  end
end
