require "abstract_unit"
require "active_support/number_helper"
require "active_support/core_ext/hash/keys"

module ActiveSupport
  class NumberHelperI18nTest < ActiveSupport::TestCase
    include ActiveSupport::NumberHelper

    def setup
      I18n.backend.store_translations "ts",
        number: {
        format: { precision: 3, delimiter: ",", separator: ".", significant: false, strip_insignificant_zeros: false },
        currency: { format: { unit: "&$", format: "%u - %n", negative_format: "(%u - %n)", precision: 2 } },
        human: {
          format: {
            precision: 2,
            significant: true,
            strip_insignificant_zeros: true
          },
          storage_units: {
            format: "%n %u",
            units: {
              byte: "b",
              kb: "k"
            }
          },
          decimal_units: {
            format: "%n %u",
            units: {
              deci: { one: "Tenth", other: "Tenths" },
              unit: "u",
              ten: { one: "Ten", other: "Tens" },
              thousand: "t",
              million: "m",
              billion: "b",
              trillion: "t" ,
              quadrillion: "q"
            }
          }
        },
        percentage: { format: { delimiter: "", precision: 2, strip_insignificant_zeros: true } },
        precision: { format: { delimiter: "", significant: true } }
      },
      custom_units_for_number_to_human: { mili: "mm", centi: "cm", deci: "dm", unit: "m", ten: "dam", hundred: "hm", thousand: "km" }
    end

    def teardown
      I18n.backend.reload!
    end

    def test_number_to_i18n_currency
      assert_equal("&$ - 10.00", number_to_currency(10, locale: "ts"))
      assert_equal("(&$ - 10.00)", number_to_currency(-10, locale: "ts"))
      assert_equal("-10.00 - &$", number_to_currency(-10, locale: "ts", format: "%n - %u"))
    end

    def test_number_to_currency_with_empty_i18n_store
      assert_equal("$10.00", number_to_currency(10, locale: "empty"))
      assert_equal("-$10.00", number_to_currency(-10, locale: "empty"))
    end

    def test_locale_default_format_has_precedence_over_helper_defaults
      I18n.backend.store_translations "ts",
        number: { format: { separator: ";" } }

      assert_equal("&$ - 10;00", number_to_currency(10, locale: "ts"))
    end

    def test_number_to_currency_without_currency_negative_format
      I18n.backend.store_translations "no_negative_format", number: {
        currency: { format: { unit: "@", format: "%n %u" } }
      }

      assert_equal("-10.00 @", number_to_currency(-10, locale: "no_negative_format"))
    end

    def test_number_with_i18n_precision
      #Delimiter was set to ""
      assert_equal("10000", number_to_rounded(10000, locale: "ts"))

      #Precision inherited and significant was set
      assert_equal("1.00", number_to_rounded(1.0, locale: "ts"))
    end

    def test_number_with_i18n_precision_and_empty_i18n_store
      assert_equal("123456789.123", number_to_rounded(123456789.123456789, locale: "empty"))
      assert_equal("1.000", number_to_rounded(1.0000, locale: "empty"))
    end

    def test_number_with_i18n_delimiter
      #Delimiter "," and separator "."
      assert_equal("1,000,000.234", number_to_delimited(1000000.234, locale: "ts"))
    end

    def test_number_with_i18n_delimiter_and_empty_i18n_store
      assert_equal("1,000,000.234", number_to_delimited(1000000.234, locale: "empty"))
    end

    def test_number_to_i18n_percentage
      # to see if strip_insignificant_zeros is true
      assert_equal("1%", number_to_percentage(1, locale: "ts"))
      # precision is 2, significant should be inherited
      assert_equal("1.24%", number_to_percentage(1.2434, locale: "ts"))
      # no delimiter
      assert_equal("12434%", number_to_percentage(12434, locale: "ts"))
    end

    def test_number_to_i18n_percentage_and_empty_i18n_store
      assert_equal("1.000%", number_to_percentage(1, locale: "empty"))
      assert_equal("1.243%", number_to_percentage(1.2434, locale: "empty"))
      assert_equal("12434.000%", number_to_percentage(12434, locale: "empty"))
    end

    def test_number_to_i18n_human_size
      #b for bytes and k for kbytes
      assert_equal("2 k", number_to_human_size(2048, locale: "ts"))
      assert_equal("42 b", number_to_human_size(42, locale: "ts"))
    end

    def test_number_to_i18n_human_size_with_empty_i18n_store
      assert_equal("2 KB", number_to_human_size(2048, locale: "empty"))
      assert_equal("42 Bytes", number_to_human_size(42, locale: "empty"))
    end

    def test_number_to_human_with_default_translation_scope
      #Using t for thousand
      assert_equal "2 t", number_to_human(2000, locale: "ts")
      #Significant was set to true with precision 2, using b for billion
      assert_equal "1.2 b", number_to_human(1234567890, locale: "ts")
      #Using pluralization (Ten/Tens and Tenth/Tenths)
      assert_equal "1 Tenth", number_to_human(0.1, locale: "ts")
      assert_equal "1.3 Tenth", number_to_human(0.134, locale: "ts")
      assert_equal "2 Tenths", number_to_human(0.2, locale: "ts")
      assert_equal "1 Ten", number_to_human(10, locale: "ts")
      assert_equal "1.2 Ten", number_to_human(12, locale: "ts")
      assert_equal "2 Tens", number_to_human(20, locale: "ts")
    end

    def test_number_to_human_with_empty_i18n_store
      assert_equal "2 Thousand", number_to_human(2000, locale: "empty")
      assert_equal "1.23 Billion", number_to_human(1234567890, locale: "empty")
    end

    def test_number_to_human_with_custom_translation_scope
      #Significant was set to true with precision 2, with custom translated units
      assert_equal "4.3 cm", number_to_human(0.0432, locale: "ts", units: :custom_units_for_number_to_human)
    end
  end
end
