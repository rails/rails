# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')

class I18nLocaleTagSimpleTest < Test::Unit::TestCase
  include I18n::Locale

  test "returns 'de' as the language subtag in lowercase" do
    assert_equal %w(de Latn DE), Tag::Simple.new('de-Latn-DE').subtags
  end

  test "returns a formatted tag string from #to_s" do
    assert_equal 'de-Latn-DE', Tag::Simple.new('de-Latn-DE').to_s
  end

  test "returns an array containing the formatted subtags from #to_a" do
    assert_equal %w(de Latn DE), Tag::Simple.new('de-Latn-DE').to_a
  end

  # Tag inheritance

  test "#parent returns 'de-Latn' as the parent of 'de-Latn-DE'" do
    assert_equal 'de-Latn', Tag::Simple.new('de-Latn-DE').parent.to_s
  end

  test "#parent returns 'de' as the parent of 'de-Latn'" do
    assert_equal 'de', Tag::Simple.new('de-Latn').parent.to_s
  end

  test "#self_and_parents returns an array of 3 tags for 'de-Latn-DE'" do
    assert_equal %w(de-Latn-DE de-Latn de), Tag::Simple.new('de-Latn-DE').self_and_parents.map { |tag| tag.to_s}
  end
end
