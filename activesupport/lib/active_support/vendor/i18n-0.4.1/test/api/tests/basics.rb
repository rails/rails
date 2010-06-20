# encoding: utf-8

module Tests
  module Api
    module Basics
      def test_available_locales
        store_translations('de', :foo => 'bar')
        store_translations('en', :foo => 'foo')

        assert I18n.available_locales.include?(:de)
        assert I18n.available_locales.include?(:en)
      end

      def test_delete_value
        store_translations(:to_be_deleted => 'bar')
        assert_equal 'bar', I18n.t('to_be_deleted', :default => 'baz')

        I18n.cache_store.clear if I18n.respond_to?(:cache_store) && I18n.cache_store
        store_translations(:to_be_deleted => nil)
        assert_equal 'baz', I18n.t('to_be_deleted', :default => 'baz')
      end
    end
  end
end
