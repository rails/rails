# encoding: utf-8

require File.expand_path(File.dirname(__FILE__) + '/../../test_helper')

include I18n::Locale

class I18nFallbacksDefaultsTest < Test::Unit::TestCase
  def teardown
    I18n.default_locale = :en
  end

  test "defaults reflect the I18n.default_locale if no default has been set manually" do
    I18n.default_locale = :'en-US'
    fallbacks = Fallbacks.new
    assert_equal [:'en-US', :en], fallbacks.defaults
  end

  test "defaults reflect a manually passed default locale if any" do
    fallbacks = Fallbacks.new(:'fi-FI')
    assert_equal [:'fi-FI', :fi], fallbacks.defaults
    I18n.default_locale = :'de-DE'
    assert_equal [:'fi-FI', :fi], fallbacks.defaults
  end

  test "defaults allows to set multiple defaults" do
    fallbacks = Fallbacks.new(:'fi-FI', :'se-FI')
    assert_equal [:'fi-FI', :fi, :'se-FI', :se], fallbacks.defaults
  end
end

class I18nFallbacksComputationTest < Test::Unit::TestCase
  def setup
    @fallbacks = Fallbacks.new(:'en-US')
  end

  test "with no mappings defined it returns [:es, :en-US] for :es" do
    assert_equal [:es, :"en-US", :en], @fallbacks[:es]
  end

  test "with no mappings defined it returns [:es-ES, :es, :en-US] for :es-ES" do
    assert_equal [:"es-ES", :es, :"en-US", :en], @fallbacks[:"es-ES"]
  end

  test "with no mappings defined it returns [:es-MX, :es, :en-US] for :es-MX" do
    assert_equal [:"es-MX", :es, :"en-US", :en], @fallbacks[:"es-MX"]
  end

  test "with no mappings defined it returns [:es-Latn-ES, :es-Latn, :es, :en-US] for :es-Latn-ES" do
    assert_equal [:"es-Latn-ES", :"es-Latn", :es, :"en-US", :en], @fallbacks[:'es-Latn-ES']
  end

  test "with no mappings defined it returns [:en, :en-US] for :en" do
    assert_equal [:en, :"en-US"], @fallbacks[:en]
  end

  test "with no mappings defined it returns [:en-US, :en] for :en-US (special case: locale == default)" do
    assert_equal [:"en-US", :en], @fallbacks[:"en-US"]
  end

  # Most people who speak Catalan also live in Spain, so it is safe to assume
  # that they also speak Spanish as spoken in Spain.
  test "with a Catalan mapping defined it returns [:ca, :es-ES, :es, :en-US] for :ca" do
    @fallbacks.map(:ca => :"es-ES")
    assert_equal [:ca, :"es-ES", :es, :"en-US", :en], @fallbacks[:ca]
  end

  test "with a Catalan mapping defined it returns [:ca-ES, :ca, :es-ES, :es, :en-US] for :ca-ES" do
    @fallbacks.map(:ca => :"es-ES")
    assert_equal [:"ca-ES", :ca, :"es-ES", :es, :"en-US", :en], @fallbacks[:"ca-ES"]
  end

  # People who speak Arabic as spoken in Palestine often times also speak
  # Hebrew as spoken in Israel. However it is in no way safe to assume that
  # everybody who speaks Arabic also speaks Hebrew.

  test "with a Hebrew mapping defined it returns [:ar, :en-US] for :ar" do
    @fallbacks.map(:"ar-PS" => :"he-IL")
    assert_equal [:ar, :"en-US", :en], @fallbacks[:ar]
  end

  test "with a Hebrew mapping defined it returns [:ar-EG, :ar, :en-US] for :ar-EG" do
    @fallbacks.map(:"ar-PS" => :"he-IL")
    assert_equal [:"ar-EG", :ar, :"en-US", :en], @fallbacks[:"ar-EG"]
  end

  test "with a Hebrew mapping defined it returns [:ar-PS, :ar, :he-IL, :he, :en-US] for :ar-PS" do
    @fallbacks.map(:"ar-PS" => :"he-IL")
    assert_equal [:"ar-PS", :ar, :"he-IL", :he, :"en-US", :en], @fallbacks[:"ar-PS"]
  end

  # Sami people live in several scandinavian countries. In Finnland many people
  # know Swedish and Finnish. Thus, it can be assumed that Sami living in
  # Finnland also speak Swedish and Finnish.

  test "with a Sami mapping defined it returns [:sms-FI, :sms, :se-FI, :se, :fi-FI, :fi, :en-US] for :sms-FI" do
    @fallbacks.map(:sms => [:"se-FI", :"fi-FI"])
    assert_equal [:"sms-FI", :sms, :"se-FI", :se, :"fi-FI", :fi, :"en-US", :en], @fallbacks[:"sms-FI"]
  end

  # Austrian people understand German as spoken in Germany

  test "with a German mapping defined it returns [:de, :en-US] for de" do
    @fallbacks.map(:"de-AT" => :"de-DE")
    assert_equal [:de, :"en-US", :en], @fallbacks[:"de"]
  end

  test "with a German mapping defined it returns [:de-DE, :de, :en-US] for de-DE" do
    @fallbacks.map(:"de-AT" => :"de-DE")
    assert_equal [:"de-DE", :de, :"en-US", :en], @fallbacks[:"de-DE"]
  end

  test "with a German mapping defined it returns [:de-AT, :de, :de-DE, :en-US] for de-AT" do
    @fallbacks.map(:"de-AT" => :"de-DE")
    assert_equal [:"de-AT", :de, :"de-DE", :"en-US", :en], @fallbacks[:"de-AT"]
  end

  # Mapping :de => :en, :he => :en

  test "with a mapping :de => :en, :he => :en defined it returns [:de, :en] for :de" do
    assert_equal [:de, :"en-US", :en], @fallbacks[:de]
  end

  test "with a mapping :de => :en, :he => :en defined it [:he, :en] for :de" do
    assert_equal [:he, :"en-US", :en], @fallbacks[:he]
  end
end
