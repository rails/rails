require 'abstract_unit'

class NumberHelperI18nTests < Test::Unit::TestCase
  include ActionView::Helpers::NumberHelper

  attr_reader :request

  uses_mocha 'number_helper_i18n_tests' do
    def setup
      @number_defaults = { :precision => 3, :delimiter => ',', :separator => '.' }
      @currency_defaults = { :unit => '$', :format => '%u%n', :precision => 2 }
      @human_defaults = { :precision => 1 }
      @percentage_defaults = { :delimiter => '' }
      @precision_defaults = { :delimiter => '' }

      I18n.backend.store_translations 'en-US', :number => { :format => @number_defaults,
        :currency => { :format => @currency_defaults }, :human => @human_defaults }
    end

    def test_number_to_currency_translates_currency_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en-US', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.currency.format', :locale => 'en-US',
                                    :raise => true).returns(@currency_defaults)
      number_to_currency(1, :locale => 'en-US')
    end

    def test_number_with_precision_translates_number_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en-US', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.precision.format', :locale => 'en-US',
                                    :raise => true).returns(@precision_defaults)
      number_with_precision(1, :locale => 'en-US')
    end

    def test_number_with_delimiter_translates_number_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en-US', :raise => true).returns(@number_defaults)
      number_with_delimiter(1, :locale => 'en-US')
    end

    def test_number_to_percentage_translates_number_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en-US', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.percentage.format', :locale => 'en-US',
                                    :raise => true).returns(@percentage_defaults)
      number_to_percentage(1, :locale => 'en-US')
    end

    def test_number_to_human_size_translates_human_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en-US', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.human.format', :locale => 'en-US',
                                    :raise => true).returns(@human_defaults)
      # can't be called with 1 because this directly returns without calling I18n.translate
      number_to_human_size(1025, :locale => 'en-US')
    end
  end
end
