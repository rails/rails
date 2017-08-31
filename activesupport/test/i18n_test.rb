# frozen_string_literal: true

require "abstract_unit"
require "active_support/time"
require "active_support/core_ext/array/conversions"

class I18nTest < ActiveSupport::TestCase
  def setup
    @date = Date.parse("2008-7-2")
    @time = Time.utc(2008, 7, 2, 16, 47, 1)
  end

  def test_time_zone_localization_with_default_format
    now = Time.local(2000)
    assert_equal now.strftime("%a, %d %b %Y %H:%M:%S %z"), I18n.localize(now)
  end

  def test_date_localization_should_use_default_format
    assert_equal @date.strftime("%Y-%m-%d"), I18n.localize(@date)
  end

  def test_date_localization_with_default_format
    assert_equal @date.strftime("%Y-%m-%d"), I18n.localize(@date, format: :default)
  end

  def test_date_localization_with_short_format
    assert_equal @date.strftime("%b %d"), I18n.localize(@date, format: :short)
  end

  def test_date_localization_with_long_format
    assert_equal @date.strftime("%B %d, %Y"), I18n.localize(@date, format: :long)
  end

  def test_time_localization_should_use_default_format
    assert_equal @time.strftime("%a, %d %b %Y %H:%M:%S %z"), I18n.localize(@time)
  end

  def test_time_localization_with_default_format
    assert_equal @time.strftime("%a, %d %b %Y %H:%M:%S %z"), I18n.localize(@time, format: :default)
  end

  def test_time_localization_with_short_format
    assert_equal @time.strftime("%d %b %H:%M"), I18n.localize(@time, format: :short)
  end

  def test_time_localization_with_long_format
    assert_equal @time.strftime("%B %d, %Y %H:%M"), I18n.localize(@time, format: :long)
  end

  def test_day_names
    assert_equal Date::DAYNAMES, I18n.translate(:'date.day_names')
  end

  def test_abbr_day_names
    assert_equal Date::ABBR_DAYNAMES, I18n.translate(:'date.abbr_day_names')
  end

  def test_month_names
    assert_equal Date::MONTHNAMES, I18n.translate(:'date.month_names')
  end

  def test_abbr_month_names
    assert_equal Date::ABBR_MONTHNAMES, I18n.translate(:'date.abbr_month_names')
  end

  def test_date_order
    assert_equal %w(year month day), I18n.translate(:'date.order')
  end

  def test_time_am
    assert_equal "am", I18n.translate(:'time.am')
  end

  def test_time_pm
    assert_equal "pm", I18n.translate(:'time.pm')
  end

  def test_words_connector
    assert_equal ", ", I18n.translate(:'support.array.words_connector')
  end

  def test_two_words_connector
    assert_equal " and ", I18n.translate(:'support.array.two_words_connector')
  end

  def test_last_word_connector
    assert_equal ", and ", I18n.translate(:'support.array.last_word_connector')
  end

  def test_to_sentence
    default_two_words_connector = I18n.translate(:'support.array.two_words_connector')
    default_last_word_connector = I18n.translate(:'support.array.last_word_connector')
    assert_equal "a, b, and c", %w[a b c].to_sentence
    I18n.backend.store_translations "en", support: { array: { two_words_connector: " & " } }
    assert_equal "a & b", %w[a b].to_sentence
    I18n.backend.store_translations "en", support: { array: { last_word_connector: " and " } }
    assert_equal "a, b and c", %w[a b c].to_sentence
  ensure
    I18n.backend.store_translations "en", support: { array: { two_words_connector: default_two_words_connector } }
    I18n.backend.store_translations "en", support: { array: { last_word_connector: default_last_word_connector } }
  end

  def test_to_sentence_with_empty_i18n_store
    assert_equal "a, b, and c", %w[a b c].to_sentence(locale: "empty")
  end
end
