require 'abstract_unit'

class NumberHelperI18nTests < Test::Unit::TestCase
  include ActionView::Helpers::NumberHelper

  attr_reader :request

  uses_mocha 'number_helper_i18n_tests' do
    def setup
      @number_defaults = { :precision => 3, :delimiter => ',', :separator => '.' }
      @currency_defaults = { :unit => '$', :format => '%u%n', :precision => 2 }
      @human_defaults = { :precision => 1 }
      @human_storage_units_format_default = "%n %u"
      @human_storage_units_units_byte_other = "Bytes"
      @human_storage_units_units_kb_other = "KB"
      @percentage_defaults = { :delimiter => '' }
      @precision_defaults = { :delimiter => '' }

      I18n.backend.store_translations 'en', :number => { :format => @number_defaults,
        :currency => { :format => @currency_defaults }, :human => @human_defaults }
    end

    def test_number_to_currency_translates_currency_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.currency.format', :locale => 'en',
                                    :raise => true).returns(@currency_defaults)
      number_to_currency(1, :locale => 'en')
    end

    def test_number_with_precision_translates_number_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.precision.format', :locale => 'en',
                                    :raise => true).returns(@precision_defaults)
      number_with_precision(1, :locale => 'en')
    end

    def test_number_with_delimiter_translates_number_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en', :raise => true).returns(@number_defaults)
      number_with_delimiter(1, :locale => 'en')
    end

    def test_number_to_percentage_translates_number_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.percentage.format', :locale => 'en',
                                    :raise => true).returns(@percentage_defaults)
      number_to_percentage(1, :locale => 'en')
    end

    def test_number_to_human_size_translates_human_formats
      I18n.expects(:translate).with(:'number.format', :locale => 'en', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.human.format', :locale => 'en',
                                    :raise => true).returns(@human_defaults)
      I18n.expects(:translate).with(:'number.human.storage_units.format', :locale => 'en',
                                    :raise => true).returns(@human_storage_units_format_default)
      I18n.expects(:translate).with(:'number.human.storage_units.units.kb', :locale => 'en', :count => 2,
                                    :raise => true).returns(@human_storage_units_units_kb_other)
      # 2KB
      number_to_human_size(2048, :locale => 'en')

      I18n.expects(:translate).with(:'number.format', :locale => 'en', :raise => true).returns(@number_defaults)
      I18n.expects(:translate).with(:'number.human.format', :locale => 'en',
                                    :raise => true).returns(@human_defaults)
      I18n.expects(:translate).with(:'number.human.storage_units.format', :locale => 'en',
                                    :raise => true).returns(@human_storage_units_format_default)
      I18n.expects(:translate).with(:'number.human.storage_units.units.byte', :locale => 'en', :count => 42,
                                    :raise => true).returns(@human_storage_units_units_byte_other)
      # 42 Bytes
      number_to_human_size(42, :locale => 'en')
    end
  end
end
