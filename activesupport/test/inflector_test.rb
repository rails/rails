# frozen_string_literal: true

require_relative "abstract_unit"
require "active_support/inflector"

require_relative "inflector_test_cases"
require_relative "constantize_test_cases"

class InflectorTest < ActiveSupport::TestCase
  include InflectorTestCases
  include ConstantizeTestCases

  def setup
    # Dups the singleton before each test, restoring the original inflections later.
    #
    # This helper is implemented by setting @__instance__ because in some tests
    # there are module functions that access ActiveSupport::Inflector.inflections,
    # so we need to replace the singleton itself.
    @original_inflections = ActiveSupport::Inflector::Inflections.instance_variable_get(:@__instance__)[:en]
    ActiveSupport::Inflector::Inflections.instance_variable_set(:@__instance__, en: @original_inflections.dup)
  end

  def teardown
    ActiveSupport::Inflector::Inflections.instance_variable_set(:@__instance__, en: @original_inflections)
  end

  def test_pluralize_plurals
    assert_equal "plurals", ActiveSupport::Inflector.pluralize("plurals")
    assert_equal "Plurals", ActiveSupport::Inflector.pluralize("Plurals")
  end

  def test_pluralize_empty_string
    assert_equal "", ActiveSupport::Inflector.pluralize("")
  end

  def test_pluralize_with_fallback
    I18n.stub(:default_locale, :"en-GB") do
      assert_equal "days", ActiveSupport::Inflector.pluralize("day")
    end
  end

  test "uncountability of ascii word" do
    word = "HTTP"
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.uncountable word
    end

    assert_equal word, ActiveSupport::Inflector.pluralize(word)
    assert_equal word, ActiveSupport::Inflector.singularize(word)
    assert_equal ActiveSupport::Inflector.pluralize(word), ActiveSupport::Inflector.singularize(word)

    ActiveSupport::Inflector.inflections.uncountables.pop
  end

  test "uncountability of non-ascii word" do
    word = "猫"
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.uncountable word
    end

    assert_equal word, ActiveSupport::Inflector.pluralize(word)
    assert_equal word, ActiveSupport::Inflector.singularize(word)
    assert_equal ActiveSupport::Inflector.pluralize(word), ActiveSupport::Inflector.singularize(word)

    ActiveSupport::Inflector.inflections.uncountables.pop
  end

  ActiveSupport::Inflector.inflections.uncountable.each do |word|
    define_method "test_uncountability_of_#{word}" do
      assert_equal word, ActiveSupport::Inflector.singularize(word)
      assert_equal word, ActiveSupport::Inflector.pluralize(word)
      assert_equal ActiveSupport::Inflector.pluralize(word), ActiveSupport::Inflector.singularize(word)
    end
  end

  def test_uncountable_word_is_not_greedy
    uncountable_word = "ors"
    countable_word = "sponsor"

    ActiveSupport::Inflector.inflections.uncountable << uncountable_word

    assert_equal uncountable_word, ActiveSupport::Inflector.singularize(uncountable_word)
    assert_equal uncountable_word, ActiveSupport::Inflector.pluralize(uncountable_word)
    assert_equal ActiveSupport::Inflector.pluralize(uncountable_word), ActiveSupport::Inflector.singularize(uncountable_word)

    assert_equal "sponsor", ActiveSupport::Inflector.singularize(countable_word)
    assert_equal "sponsors", ActiveSupport::Inflector.pluralize(countable_word)
    assert_equal "sponsor", ActiveSupport::Inflector.singularize(ActiveSupport::Inflector.pluralize(countable_word))
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_pluralize_singular_#{singular}" do
      assert_equal(plural, ActiveSupport::Inflector.pluralize(singular))
      assert_equal(plural.capitalize, ActiveSupport::Inflector.pluralize(singular.capitalize))
    end
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_singularize_plural_#{plural}" do
      assert_equal(singular, ActiveSupport::Inflector.singularize(plural))
      assert_equal(singular.capitalize, ActiveSupport::Inflector.singularize(plural.capitalize))
    end
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_pluralize_plural_#{plural}" do
      assert_equal(plural, ActiveSupport::Inflector.pluralize(plural))
      assert_equal(plural.capitalize, ActiveSupport::Inflector.pluralize(plural.capitalize))
    end

    define_method "test_singularize_singular_#{singular}" do
      assert_equal(singular, ActiveSupport::Inflector.singularize(singular))
      assert_equal(singular.capitalize, ActiveSupport::Inflector.singularize(singular.capitalize))
    end
  end

  def test_overwrite_previous_inflectors
    assert_equal("series", ActiveSupport::Inflector.singularize("series"))
    ActiveSupport::Inflector.inflections.singular "series", "serie"
    assert_equal("serie", ActiveSupport::Inflector.singularize("series"))
  end

  MixtureToTitleCase.each_with_index do |(before, titleized), index|
    define_method "test_titleize_mixture_to_title_case_#{index}" do
      assert_equal(titleized, ActiveSupport::Inflector.titleize(before), "mixture \
        to TitleCase failed for #{before}")
    end
  end

  MixtureToTitleCaseWithKeepIdSuffix.each_with_index do |(before, titleized), index|
    define_method "test_titleize_with_keep_id_suffix_mixture_to_title_case_#{index}" do
      assert_equal(titleized, ActiveSupport::Inflector.titleize(before, keep_id_suffix: true),
        "mixture to TitleCase with keep_id_suffix failed for #{before}")
    end
  end

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, ActiveSupport::Inflector.camelize(underscore))
    end
  end

  def test_camelize_with_true_upcases_the_first_letter
    assert_equal("Capital", ActiveSupport::Inflector.camelize("Capital", true))
    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital", true))
  end

  def test_camelize_with_upper_upcases_the_first_letter
    assert_equal("Capital", ActiveSupport::Inflector.camelize("Capital", :upper))
    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital", :upper))
  end

  def test_camelize_with_false_downcases_the_first_letter
    assert_equal("capital", ActiveSupport::Inflector.camelize("Capital", false))
    assert_equal("capital", ActiveSupport::Inflector.camelize("capital", false))
  end

  def test_camelize_with_nil_downcases_the_first_letter
    assert_equal("capital", ActiveSupport::Inflector.camelize("Capital", nil))
    assert_equal("capital", ActiveSupport::Inflector.camelize("capital", nil))
  end

  def test_camelize_with_lower_downcases_the_first_letter
    assert_equal("capital", ActiveSupport::Inflector.camelize("Capital", :lower))
    assert_equal("capital", ActiveSupport::Inflector.camelize("capital", :lower))
  end

  def test_camelize_with_any_other_arg_upcases_the_first_letter
    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital", :true))
    assert_equal("Capital", ActiveSupport::Inflector.camelize("Capital", :true))

    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital", :false))
    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital", :foo))
    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital", 42))
    assert_equal("Capital", ActiveSupport::Inflector.camelize("capital"))
  end

  def test_camelize_with_underscores
    assert_equal("CamelCase", ActiveSupport::Inflector.camelize("Camel_Case"))
  end

  def test_acronyms
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym("API")
      inflect.acronym("HTML")
      inflect.acronym("HTTP")
      inflect.acronym("RESTful")
      inflect.acronym("W3C")
      inflect.acronym("PhD")
      inflect.acronym("RoR")
      inflect.acronym("SSL")
    end

    #  camelize             underscore            humanize              titleize
    [
      ["API",               "api",                "API",                "API"],
      ["APIController",     "api_controller",     "API controller",     "API Controller"],
      ["Nokogiri::HTML",    "nokogiri/html",      "Nokogiri/HTML",      "Nokogiri/HTML"],
      ["HTTPAPI",           "http_api",           "HTTP API",           "HTTP API"],
      ["HTTP::Get",         "http/get",           "HTTP/get",           "HTTP/Get"],
      ["SSLError",          "ssl_error",          "SSL error",          "SSL Error"],
      ["RESTful",           "restful",            "RESTful",            "RESTful"],
      ["RESTfulController", "restful_controller", "RESTful controller", "RESTful Controller"],
      ["Nested::RESTful",   "nested/restful",     "Nested/RESTful",     "Nested/RESTful"],
      ["IHeartW3C",         "i_heart_w3c",        "I heart W3C",        "I Heart W3C"],
      ["PhDRequired",       "phd_required",       "PhD required",       "PhD Required"],
      ["IRoRU",             "i_ror_u",            "I RoR u",            "I RoR U"],
      ["RESTfulHTTPAPI",    "restful_http_api",   "RESTful HTTP API",   "RESTful HTTP API"],
      ["HTTP::RESTful",     "http/restful",       "HTTP/RESTful",       "HTTP/RESTful"],
      ["HTTP::RESTfulAPI",  "http/restful_api",   "HTTP/RESTful API",   "HTTP/RESTful API"],
      ["APIRESTful",        "api_restful",        "API RESTful",        "API RESTful"],

      # misdirection
      ["Capistrano",        "capistrano",         "Capistrano",       "Capistrano"],
      ["CapiController",    "capi_controller",    "Capi controller",  "Capi Controller"],
      ["HttpsApis",         "https_apis",         "Https apis",       "Https Apis"],
      ["Html5",             "html5",              "Html5",            "Html5"],
      ["Restfully",         "restfully",          "Restfully",        "Restfully"],
      ["RoRails",           "ro_rails",           "Ro rails",         "Ro Rails"]
    ].each do |camel, under, human, title|
      assert_equal(camel, ActiveSupport::Inflector.camelize(under))
      assert_equal(camel, ActiveSupport::Inflector.camelize(camel))
      assert_not_predicate(ActiveSupport::Inflector.camelize(under), :frozen?)
      assert_not_predicate(ActiveSupport::Inflector.camelize(camel), :frozen?)

      assert_equal(under, ActiveSupport::Inflector.underscore(under))
      assert_equal(under, ActiveSupport::Inflector.underscore(camel))
      assert_not_predicate(ActiveSupport::Inflector.underscore(under), :frozen?)
      assert_not_predicate(ActiveSupport::Inflector.underscore(camel), :frozen?)

      assert_equal(title, ActiveSupport::Inflector.titleize(under))
      assert_equal(title, ActiveSupport::Inflector.titleize(camel))
      assert_not_predicate(ActiveSupport::Inflector.titleize(under), :frozen?)
      assert_not_predicate(ActiveSupport::Inflector.titleize(camel), :frozen?)

      assert_equal(human, ActiveSupport::Inflector.humanize(under))
      assert_not_predicate(ActiveSupport::Inflector.humanize(camel), :frozen?)
    end
  end

  def test_acronym_override
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym("API")
      inflect.acronym("LegacyApi")
    end

    assert_equal("LegacyApi", ActiveSupport::Inflector.camelize("legacyapi"))
    assert_equal("LegacyAPI", ActiveSupport::Inflector.camelize("legacy_api"))
    assert_equal("SomeLegacyApi", ActiveSupport::Inflector.camelize("some_legacyapi"))
    assert_equal("Nonlegacyapi", ActiveSupport::Inflector.camelize("nonlegacyapi"))
  end

  def test_acronyms_camelize_lower
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym("API")
      inflect.acronym("HTML")
    end

    assert_equal("htmlAPI", ActiveSupport::Inflector.camelize("html_api", false))
    assert_equal("htmlAPI", ActiveSupport::Inflector.camelize("htmlAPI", false))
    assert_equal("htmlAPI", ActiveSupport::Inflector.camelize("HTMLAPI", false))
  end

  def test_underscore_acronym_sequence
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym("API")
      inflect.acronym("JSON")
      inflect.acronym("HTML")
    end

    assert_equal("json_html_api", ActiveSupport::Inflector.underscore("JSONHTMLAPI"))
  end

  def test_underscore
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(underscore, ActiveSupport::Inflector.underscore(camel))
    end
    CamelToUnderscoreWithoutReverse.each do |camel, underscore|
      assert_equal(underscore, ActiveSupport::Inflector.underscore(camel))
    end
  end

  def test_camelize_with_module
    CamelWithModuleToUnderscoreWithSlash.each do |camel, underscore|
      assert_equal(camel, ActiveSupport::Inflector.camelize(underscore))
    end
  end

  def test_underscore_with_slashes
    CamelWithModuleToUnderscoreWithSlash.each do |camel, underscore|
      assert_equal(underscore, ActiveSupport::Inflector.underscore(camel))
    end
  end

  def test_demodulize
    assert_equal "Account", ActiveSupport::Inflector.demodulize("MyApplication::Billing::Account")
    assert_equal "Account", ActiveSupport::Inflector.demodulize("Account")
    assert_equal "Account", ActiveSupport::Inflector.demodulize("::Account")
    assert_equal "", ActiveSupport::Inflector.demodulize("")
  end

  def test_deconstantize
    assert_equal "MyApplication::Billing", ActiveSupport::Inflector.deconstantize("MyApplication::Billing::Account")
    assert_equal "::MyApplication::Billing", ActiveSupport::Inflector.deconstantize("::MyApplication::Billing::Account")

    assert_equal "MyApplication", ActiveSupport::Inflector.deconstantize("MyApplication::Billing")
    assert_equal "::MyApplication", ActiveSupport::Inflector.deconstantize("::MyApplication::Billing")

    assert_equal "", ActiveSupport::Inflector.deconstantize("Account")
    assert_equal "", ActiveSupport::Inflector.deconstantize("::Account")
    assert_equal "", ActiveSupport::Inflector.deconstantize("")
  end

  def test_foreign_key
    ClassNameToForeignKeyWithUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, ActiveSupport::Inflector.foreign_key(klass))
    end

    ClassNameToForeignKeyWithoutUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, ActiveSupport::Inflector.foreign_key(klass, false))
    end
  end

  def test_tableize
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(table_name, ActiveSupport::Inflector.tableize(class_name))
    end
  end

  def test_parameterize
    StringToParameterized.each do |some_string, parameterized_string|
      assert_equal(parameterized_string, ActiveSupport::Inflector.parameterize(some_string))
    end
  end

  def test_parameterize_and_normalize
    StringToParameterizedAndNormalized.each do |some_string, parameterized_string|
      assert_equal(parameterized_string, ActiveSupport::Inflector.parameterize(some_string))
    end
  end

  def test_parameterize_with_custom_separator
    StringToParameterizeWithUnderscore.each do |some_string, parameterized_string|
      assert_equal(parameterized_string, ActiveSupport::Inflector.parameterize(some_string, separator: "_"))
    end
  end

  def test_parameterize_with_multi_character_separator
    StringToParameterized.each do |some_string, parameterized_string|
      assert_equal(parameterized_string.gsub("-", "__sep__"), ActiveSupport::Inflector.parameterize(some_string, separator: "__sep__"))
    end
  end

  def test_parameterize_with_locale
    word = "Fünf autos"
    I18n.backend.store_translations(:de, i18n: { transliterate: { rule: { "ü" => "ue" } } })
    assert_equal("fuenf-autos", ActiveSupport::Inflector.parameterize(word, locale: :de))
  end

  def test_classify
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(class_name, ActiveSupport::Inflector.classify(table_name))
      assert_equal(class_name, ActiveSupport::Inflector.classify("table_prefix." + table_name))
    end
  end

  def test_classify_with_symbol
    assert_nothing_raised do
      assert_equal "FooBar", ActiveSupport::Inflector.classify(:foo_bars)
    end
  end

  def test_classify_with_leading_schema_name
    assert_equal "FooBar", ActiveSupport::Inflector.classify("schema.foo_bar")
  end

  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human, ActiveSupport::Inflector.humanize(underscore))
    end
  end

  def test_humanize_nil
    assert_equal("", ActiveSupport::Inflector.humanize(nil))
  end

  def test_humanize_without_capitalize
    UnderscoreToHumanWithoutCapitalize.each do |underscore, human|
      assert_equal(human, ActiveSupport::Inflector.humanize(underscore, capitalize: false))
    end
  end

  def test_humanize_with_keep_id_suffix
    UnderscoreToHumanWithKeepIdSuffix.each do |underscore, human|
      assert_equal(human, ActiveSupport::Inflector.humanize(underscore, keep_id_suffix: true))
    end
  end

  def test_humanize_by_rule
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.human(/_cnt$/i, '\1_count')
      inflect.human(/^prefx_/i, '\1')
    end
    assert_equal("Jargon count", ActiveSupport::Inflector.humanize("jargon_cnt"))
    assert_equal("Request", ActiveSupport::Inflector.humanize("prefx_request"))
  end

  def test_humanize_by_string
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.human("col_rpted_bugs", "Reported bugs")
    end
    assert_equal("Reported bugs", ActiveSupport::Inflector.humanize("col_rpted_bugs"))
    assert_equal("Col rpted bugs", ActiveSupport::Inflector.humanize("COL_rpted_bugs"))
  end

  def test_humanize_with_acronyms
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym "LAX"
      inflect.acronym "SFO"
    end
    assert_equal("LAX roundtrip to SFO", ActiveSupport::Inflector.humanize("LAX ROUNDTRIP TO SFO"))
    assert_equal("LAX roundtrip to SFO", ActiveSupport::Inflector.humanize("LAX ROUNDTRIP TO SFO", capitalize: false))
    assert_equal("LAX roundtrip to SFO", ActiveSupport::Inflector.humanize("lax roundtrip to sfo"))
    assert_equal("LAX roundtrip to SFO", ActiveSupport::Inflector.humanize("lax roundtrip to sfo", capitalize: false))
    assert_equal("LAX roundtrip to SFO", ActiveSupport::Inflector.humanize("Lax Roundtrip To Sfo"))
    assert_equal("LAX roundtrip to SFO", ActiveSupport::Inflector.humanize("Lax Roundtrip To Sfo", capitalize: false))
  end

  def test_constantize
    run_constantize_tests_on do |string|
      ActiveSupport::Inflector.constantize(string)
    end
  end

  def test_safe_constantize
    run_safe_constantize_tests_on do |string|
      ActiveSupport::Inflector.safe_constantize(string)
    end
  end

  def test_ordinal
    OrdinalNumbers.each do |number, ordinalized|
      assert_equal(ordinalized, number + ActiveSupport::Inflector.ordinal(number))
    end
  end

  def test_ordinalize
    OrdinalNumbers.each do |number, ordinalized|
      assert_equal(ordinalized, ActiveSupport::Inflector.ordinalize(number))
    end
  end

  def test_dasherize
    UnderscoresToDashes.each do |underscored, dasherized|
      assert_equal(dasherized, ActiveSupport::Inflector.dasherize(underscored))
    end
  end

  def test_underscore_as_reverse_of_dasherize
    UnderscoresToDashes.each_key do |underscored|
      assert_equal(underscored, ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.dasherize(underscored)))
    end
  end

  def test_underscore_to_lower_camel
    UnderscoreToLowerCamel.each do |underscored, lower_camel|
      assert_equal(lower_camel, ActiveSupport::Inflector.camelize(underscored, false))
    end
  end

  def test_symbol_to_lower_camel
    SymbolToLowerCamel.each do |symbol, lower_camel|
      assert_equal(lower_camel, ActiveSupport::Inflector.camelize(symbol, false))
    end
  end

  %w{plurals singulars uncountables humans}.each do |inflection_type|
    class_eval <<-RUBY, __FILE__, __LINE__ + 1
      def test_clear_#{inflection_type}
        ActiveSupport::Inflector.inflections.clear :#{inflection_type}
        assert ActiveSupport::Inflector.inflections.#{inflection_type}.empty?, \"#{inflection_type} inflections should be empty after clear :#{inflection_type}\"
      end
    RUBY
  end

  def test_clear_acronyms_resets_to_reusable_state
    ActiveSupport::Inflector.inflections.clear(:acronyms)

    assert_empty ActiveSupport::Inflector.inflections.acronyms

    ActiveSupport::Inflector.inflections do |inflect|
      inflect.acronym "HTML"
    end

    assert_equal "HTML", "html".titleize
  end

  def test_inflector_locality
    ActiveSupport::Inflector.inflections(:es) do |inflect|
      inflect.plural(/$/, "s")
      inflect.plural(/z$/i, "ces")

      inflect.singular(/s$/, "")
      inflect.singular(/es$/, "")

      inflect.irregular("el", "los")

      inflect.uncountable("agua")
    end

    assert_equal("hijos", "hijo".pluralize(:es))
    assert_equal("luces", "luz".pluralize(:es))
    assert_equal("luzs", "luz".pluralize)

    assert_equal("sociedad", "sociedades".singularize(:es))
    assert_equal("sociedade", "sociedades".singularize)

    assert_equal("los", "el".pluralize(:es))
    assert_equal("els", "el".pluralize)

    assert_equal("agua", "agua".pluralize(:es))
    assert_equal("aguas", "agua".pluralize)

    ActiveSupport::Inflector.inflections(:es) { |inflect| inflect.clear }

    assert_empty ActiveSupport::Inflector.inflections(:es).plurals
    assert_empty ActiveSupport::Inflector.inflections(:es).singulars
    assert_empty ActiveSupport::Inflector.inflections(:es).uncountables
    assert_not_empty ActiveSupport::Inflector.inflections.plurals
    assert_not_empty ActiveSupport::Inflector.inflections.singulars
    assert_not_empty ActiveSupport::Inflector.inflections.uncountables
  end

  def test_clear_all
    ActiveSupport::Inflector.inflections do |inflect|
      # ensure any data is present
      inflect.plural(/(quiz)$/i, '\1zes')
      inflect.singular(/(database)s$/i, '\1')
      inflect.uncountable("series")
      inflect.human("col_rpted_bugs", "Reported bugs")
      inflect.acronym("HTML")

      inflect.clear :all

      assert_empty inflect.plurals
      assert_empty inflect.singulars
      assert_empty inflect.uncountables
      assert_empty inflect.humans
      assert_empty inflect.acronyms
    end
  end

  def test_clear_with_default
    ActiveSupport::Inflector.inflections do |inflect|
      # ensure any data is present
      inflect.plural(/(quiz)$/i, '\1zes')
      inflect.singular(/(database)s$/i, '\1')
      inflect.uncountable("series")
      inflect.human("col_rpted_bugs", "Reported bugs")
      inflect.acronym("HTML")

      inflect.clear

      assert_empty inflect.plurals
      assert_empty inflect.singulars
      assert_empty inflect.uncountables
      assert_empty inflect.humans
      assert_empty inflect.acronyms
    end
  end

  def test_clear_all_resets_camelize_and_underscore_regexes
    ActiveSupport::Inflector.inflections do |inflect|
      # ensure any data is present
      inflect.acronym("HTTP")
      assert_equal "http_s", "HTTPS".underscore
      assert_equal "Https", "https".camelize

      inflect.clear :all

      assert_empty inflect.acronyms
      assert_equal "https", "HTTPS".underscore
      assert_equal "Https", "https".camelize
    end
  end

  Irregularities.each do |singular, plural|
    define_method("test_irregularity_between_#{singular}_and_#{plural}") do
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.irregular(singular, plural)
        assert_equal singular, ActiveSupport::Inflector.singularize(plural)
        assert_equal plural, ActiveSupport::Inflector.pluralize(singular)
      end
    end
  end

  Irregularities.each do |singular, plural|
    define_method("test_pluralize_of_irregularity_#{plural}_should_be_the_same") do
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.irregular(singular, plural)
        assert_equal plural, ActiveSupport::Inflector.pluralize(plural)
      end
    end
  end

  Irregularities.each do |singular, plural|
    define_method("test_singularize_of_irregularity_#{singular}_should_be_the_same") do
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.irregular(singular, plural)
        assert_equal singular, ActiveSupport::Inflector.singularize(singular)
      end
    end
  end

  [ :all, [] ].each do |scope|
    ActiveSupport::Inflector.inflections do |inflect|
      define_method("test_clear_inflections_with_#{scope.kind_of?(Array) ? "no_arguments" : scope}") do
        # save all the inflections
        singulars, plurals, uncountables = inflect.singulars, inflect.plurals, inflect.uncountables

        # clear all the inflections
        inflect.clear(*scope)

        assert_equal [], inflect.singulars
        assert_equal [], inflect.plurals
        assert_equal [], inflect.uncountables

        # restore all the inflections
        singulars.reverse_each { |singular| inflect.singular(*singular) }
        plurals.reverse_each   { |plural|   inflect.plural(*plural) }
        inflect.uncountable(uncountables)

        assert_equal singulars, inflect.singulars
        assert_equal plurals, inflect.plurals
        assert_equal uncountables, inflect.uncountables
      end
    end
  end

  %i(plurals singulars uncountables humans).each do |scope|
    define_method("test_clear_inflections_with_#{scope}") do
      # clear the inflections
      ActiveSupport::Inflector.inflections do |inflect|
        inflect.clear(scope)
        assert_equal [], inflect.public_send(scope)
      end
    end
  end

  def test_clear_inflections_with_acronyms
    ActiveSupport::Inflector.inflections do |inflect|
      inflect.clear(:acronyms)
      assert_equal({}, inflect.acronyms)
    end
  end

  def test_output_is_not_frozen_even_if_input_is_frozen
    input = "plurals"
    assert_predicate input, :frozen?
    assert_not_predicate ActiveSupport::Inflector.pluralize(input), :frozen?
  end
end
