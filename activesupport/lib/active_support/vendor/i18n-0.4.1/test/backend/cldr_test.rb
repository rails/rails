# encoding: utf-8

begin
  require 'cldr'
rescue LoadError
  puts "Skipping tests for I18n::Backend::Cldr because the ruby-cldr gem is not installed."
end

if defined?(Cldr)
  $:.unshift(File.expand_path(File.dirname(__FILE__) + '/../')); $:.uniq!
  require 'test_helper'
  require 'i18n/backend/cldr'
  require 'date'

  class I18nBackendCldrTest < Test::Unit::TestCase
    class Backend < I18n::Backend::Simple
      include I18n::Backend::Cldr
    end

    def setup
      I18n.backend = Backend.new
      I18n.locale = :de
      I18n.load_path += Dir[locales_dir + '/cldr/**/*.{yml,rb}']
      super
    end

    # NUMBER

    test "format_number" do
      assert_equal '123.456,78', I18n.l(123456.78)
    end

    # CURRENCY

    test "format_currency" do
      assert_equal '123.456,78 EUR', I18n.l(123456.78, :currency => 'EUR')
    end

    # hu? does this actually make any sense?
    test "format_currency translating currency names" do
      assert_equal '1,00 Irisches Pfund', I18n.l(1, :currency => :IEP)
      assert_equal '2,00 Irische Pfund',  I18n.l(2, :currency => :IEP)
    end

    # PERCENT

    # this is odd but the cldr percent format does not include a fraction
    test "format_percent" do
      assert_equal '123.457 %', I18n.l(123456.78, :as => :percent)
    end

    # so we can pass a precision manually
    test "format_percent w/ precision" do
      assert_equal '123.456,70 %', I18n.l(123456.7, :as => :percent, :precision => 2)
    end

    # DATE

    def date
      Date.new(2010, 1, 1)
    end

    test "format_date :full" do
      assert_equal 'Freitag, 1. Januar 2010', I18n.l(date, :format => :full)
    end

    test "format_date :long" do
      assert_equal '1. Januar 2010', I18n.l(date, :format => :long)
    end

    test "format_date :medium" do
      assert_equal '01.01.2010', I18n.l(date)
    end

    test "format_date :short" do
      assert_equal '01.01.10', I18n.l(date, :format => :short)
    end

    # TIME

    def time
      Time.utc(2010, 1, 1, 13, 15, 17)
    end

    # TODO cldr export lacks localized timezone data
    # test "format_time :full" do
    #   assert_equal 'Freitag, 1. Januar 2010', I18n.l(time, :format => :full)
    # end

    test "format_time :long" do
      assert_equal '13:15:17 UTC', I18n.l(time, :format => :long)
    end

    test "format_time :medium" do
      assert_equal '13:15:17', I18n.l(time)
    end

    test "format_time :short" do
      assert_equal '13:15', I18n.l(time, :format => :short)
    end

    # DATETIME

    def datetime
      DateTime.new(2010, 11, 12, 13, 14, 15)
    end

    # TODO cldr export lacks localized timezone data
    # test "format_datetime :full" do
    #   assert_equal 'Thursday, 12. November 2010 13:14:15', I18n.l(datetime, :format => :full)
    # end

    test "format_datetime :long" do
      assert_equal '12. November 2010 13:14:15 +00:00', I18n.l(datetime, :format => :long)
    end

    test "format_datetime :medium" do
      assert_equal '12.11.2010 13:14:15', I18n.l(datetime)
    end

    test "format_datetime :short" do
      assert_equal '12.11.10 13:14', I18n.l(datetime, :format => :short)
    end

    test "format_datetime mixed :long + :short" do
      assert_equal '12. November 2010 13:14', I18n.l(datetime, :date_format => :long, :time_format => :short)
    end

    test "format_datetime mixed :short + :long" do
      assert_equal '12.11.10 13:14:15 +00:00', I18n.l(datetime, :date_format => :short, :time_format => :long)
    end

    # CUSTOM FORMATS

    test "can deal with customized formats data" do
      store_translations :de, :numbers => {
        :formats => {
          :decimal => {
            :patterns => {
              :default => "#,##0.###",
              :stupid  => "#"
            }
          }
        }
      }
      assert_equal '123.456,78', I18n.l(123456.78)
      assert_equal '123457',     I18n.l(123456.78, :format => :stupid)
    end
  end
end