require 'abstract_unit'

class NumberHelperI18nTests < Test::Unit::TestCase
  include ActionView::Helpers::NumberHelper
  
  attr_reader :request
  uses_mocha 'number_helper_i18n_tests' do
    def setup
      @defaults = {:separator => ".", :unit => "$", :format => "%u%n", :delimiter => ",", :precision => 2}
      I18n.backend.store_translations 'en-US', :currency => {:format => @defaults}
    end

    def test_number_to_currency_translates_currency_formats
      I18n.expects(:translate).with(:'currency.format', :locale => 'en-US').returns @defaults
      number_to_currency(1, :locale => 'en-US')
    end
  end
end