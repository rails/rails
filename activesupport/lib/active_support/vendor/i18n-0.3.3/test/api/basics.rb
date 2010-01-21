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
    end
  end
end
