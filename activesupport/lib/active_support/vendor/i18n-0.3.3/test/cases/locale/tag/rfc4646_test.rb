# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../../test_helper')

class I18nLocaleTagRfc4646ParserTest < Test::Unit::TestCase
  include I18n::Locale

  test "Rfc4646::Parser given a valid tag 'de' returns an array of subtags" do
    assert_equal ['de', nil, nil, nil, nil, nil, nil], Tag::Rfc4646::Parser.match('de')
  end

  test "Rfc4646::Parser given a valid tag 'de' returns an array of subtags" do
    assert_equal ['de', nil, 'DE', nil, nil, nil, nil], Tag::Rfc4646::Parser.match('de-DE')
  end

  test "Rfc4646::Parser given a valid lowercase tag 'de-latn-de-variant-x-phonebk' returns an array of subtags" do
    assert_equal ['de', 'latn', 'de', 'variant', nil, 'x-phonebk', nil], Tag::Rfc4646::Parser.match('de-latn-de-variant-x-phonebk')
  end

  test "Rfc4646::Parser given a valid uppercase tag 'DE-LATN-DE-VARIANT-X-PHONEBK' returns an array of subtags" do
    assert_equal ['DE', 'LATN', 'DE', 'VARIANT', nil, 'X-PHONEBK', nil], Tag::Rfc4646::Parser.match('DE-LATN-DE-VARIANT-X-PHONEBK')
  end

  test "Rfc4646::Parser given an invalid tag 'a-DE' it returns false" do
    assert_equal false, Tag::Rfc4646::Parser.match('a-DE')
  end

  test "Rfc4646::Parser given an invalid tag 'de-419-DE' it returns false" do
    assert_equal false, Tag::Rfc4646::Parser.match('de-419-DE')
  end
end

# Tag for the locale 'de-Latn-DE-Variant-a-ext-x-phonebk-i-klingon'

class I18nLocaleTagSubtagsTest < Test::Unit::TestCase
  include I18n::Locale

  def setup
    subtags = %w(de Latn DE variant a-ext x-phonebk i-klingon)
    @tag = Tag::Rfc4646.new *subtags
  end

  test "returns 'de' as the language subtag in lowercase" do
    assert_equal 'de', @tag.language
  end

  test "returns 'Latn' as the script subtag in titlecase" do
    assert_equal 'Latn', @tag.script
  end

  test "returns 'DE' as the region subtag in uppercase" do
    assert_equal 'DE', @tag.region
  end

  test "returns 'variant' as the variant subtag in lowercase" do
    assert_equal 'variant', @tag.variant
  end

  test "returns 'a-ext' as the extension subtag" do
    assert_equal 'a-ext', @tag.extension
  end

  test "returns 'x-phonebk' as the privateuse subtag" do
    assert_equal 'x-phonebk', @tag.privateuse
  end

  test "returns 'i-klingon' as the grandfathered subtag" do
    assert_equal 'i-klingon', @tag.grandfathered
  end

  test "returns a formatted tag string from #to_s" do
    assert_equal 'de-Latn-DE-variant-a-ext-x-phonebk-i-klingon', @tag.to_s
  end

  test "returns an array containing the formatted subtags from #to_a" do
    assert_equal %w(de Latn DE variant a-ext x-phonebk i-klingon), @tag.to_a
  end
end

# Tag inheritance

class I18nLocaleTagSubtagsTest < Test::Unit::TestCase
  test "#parent returns 'de-Latn-DE-variant-a-ext-x-phonebk' as the parent of 'de-Latn-DE-variant-a-ext-x-phonebk-i-klingon'" do
    tag = Tag::Rfc4646.new *%w(de Latn DE variant a-ext x-phonebk i-klingon)
    assert_equal 'de-Latn-DE-variant-a-ext-x-phonebk', tag.parent.to_s
  end

  test "#parent returns 'de-Latn-DE-variant-a-ext' as the parent of 'de-Latn-DE-variant-a-ext-x-phonebk'" do
    tag = Tag::Rfc4646.new *%w(de Latn DE variant a-ext x-phonebk)
    assert_equal 'de-Latn-DE-variant-a-ext', tag.parent.to_s
  end

  test "#parent returns 'de-Latn-DE-variant' as the parent of 'de-Latn-DE-variant-a-ext'" do
    tag = Tag::Rfc4646.new *%w(de Latn DE variant a-ext)
    assert_equal 'de-Latn-DE-variant', tag.parent.to_s
  end

  test "#parent returns 'de-Latn-DE' as the parent of 'de-Latn-DE-variant'" do
    tag = Tag::Rfc4646.new *%w(de Latn DE variant)
    assert_equal 'de-Latn-DE', tag.parent.to_s
  end

  test "#parent returns 'de-Latn' as the parent of 'de-Latn-DE'" do
    tag = Tag::Rfc4646.new *%w(de Latn DE)
    assert_equal 'de-Latn', tag.parent.to_s
  end

  test "#parent returns 'de' as the parent of 'de-Latn'" do
    tag = Tag::Rfc4646.new *%w(de Latn)
    assert_equal 'de', tag.parent.to_s
  end

  # TODO RFC4647 says: "If no language tag matches the request, the "default" value is returned."
  # where should we set the default language?
  # test "#parent returns '' as the parent of 'de'" do
  #   tag = Tag::Rfc4646.new *%w(de)
  #   assert_equal '', tag.parent.to_s
  # end

  test "#parent returns an array of 5 parents for 'de-Latn-DE-variant-a-ext-x-phonebk-i-klingon'" do
    parents = %w(de-Latn-DE-variant-a-ext-x-phonebk-i-klingon
                 de-Latn-DE-variant-a-ext-x-phonebk
                 de-Latn-DE-variant-a-ext
                 de-Latn-DE-variant
                 de-Latn-DE
                 de-Latn
                 de)
    tag = Tag::Rfc4646.new *%w(de Latn DE variant a-ext x-phonebk i-klingon)
    assert_equal parents, tag.self_and_parents.map{|tag| tag.to_s}
  end

  test "returns an array of 5 parents for 'de-Latn-DE-variant-a-ext-x-phonebk-i-klingon'" do
    parents = %w(de-Latn-DE-variant-a-ext-x-phonebk-i-klingon
                 de-Latn-DE-variant-a-ext-x-phonebk
                 de-Latn-DE-variant-a-ext
                 de-Latn-DE-variant
                 de-Latn-DE
                 de-Latn
                 de)
    tag = Tag::Rfc4646.new *%w(de Latn DE variant a-ext x-phonebk i-klingon)
    assert_equal parents, tag.self_and_parents.map{|tag| tag.to_s}
  end
end
