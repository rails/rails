require 'abstract_unit'
require 'inflector_test_cases'

module Ace
  module Base
    class Case
    end
  end
end

class InflectorTest < Test::Unit::TestCase
  include InflectorTestCases

  def test_pluralize_plurals
    assert_equal "plurals", ActiveSupport::Inflector.pluralize("plurals")
    assert_equal "Plurals", ActiveSupport::Inflector.pluralize("Plurals")
  end

  def test_pluralize_empty_string
    assert_equal "", ActiveSupport::Inflector.pluralize("")
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_pluralize_#{singular}" do
      assert_equal(plural, ActiveSupport::Inflector.pluralize(singular))
      assert_equal(plural.capitalize, ActiveSupport::Inflector.pluralize(singular.capitalize))
    end
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_singularize_#{plural}" do
      assert_equal(singular, ActiveSupport::Inflector.singularize(plural))
      assert_equal(singular.capitalize, ActiveSupport::Inflector.singularize(plural.capitalize))
    end
  end

  MixtureToTitleCase.each do |before, titleized|
    define_method "test_titleize_#{before}" do
      assert_equal(titleized, ActiveSupport::Inflector.titleize(before))
    end
  end

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, ActiveSupport::Inflector.camelize(underscore))
    end
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

  def test_classify
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(class_name, ActiveSupport::Inflector.classify(table_name))
      assert_equal(class_name, ActiveSupport::Inflector.classify("table_prefix." + table_name))
    end
  end

  def test_classify_with_symbol
    assert_nothing_raised do
      assert_equal 'FooBar', ActiveSupport::Inflector.classify(:foo_bars)
    end
  end

  def test_classify_with_leading_schema_name
    assert_equal 'FooBar', ActiveSupport::Inflector.classify('schema.foo_bar')
  end

  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human, ActiveSupport::Inflector.humanize(underscore))
    end
  end

  def test_constantize
    assert_nothing_raised { assert_equal Ace::Base::Case, ActiveSupport::Inflector.constantize("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, ActiveSupport::Inflector.constantize("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal InflectorTest, ActiveSupport::Inflector.constantize("InflectorTest") }
    assert_nothing_raised { assert_equal InflectorTest, ActiveSupport::Inflector.constantize("::InflectorTest") }
    assert_raises(NameError) { ActiveSupport::Inflector.constantize("UnknownClass") }
    assert_raises(NameError) { ActiveSupport::Inflector.constantize("An invalid string") }
    assert_raises(NameError) { ActiveSupport::Inflector.constantize("InvalidClass\n") }
  end

  def test_constantize_does_lexical_lookup
    assert_raises(NameError) { ActiveSupport::Inflector.constantize("Ace::Base::InflectorTest") }
  end

  def test_ordinal
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
    UnderscoresToDashes.each do |underscored, dasherized|
      assert_equal(underscored, ActiveSupport::Inflector.underscore(ActiveSupport::Inflector.dasherize(underscored)))
    end
  end

  def test_underscore_to_lower_camel
    UnderscoreToLowerCamel.each do |underscored, lower_camel|
      assert_equal(lower_camel, ActiveSupport::Inflector.camelize(underscored, false))
    end
  end

  %w{plurals singulars uncountables}.each do |inflection_type|
    class_eval "
      def test_clear_#{inflection_type}
        cached_values = ActiveSupport::Inflector.inflections.#{inflection_type}
        ActiveSupport::Inflector.inflections.clear :#{inflection_type}
        assert ActiveSupport::Inflector.inflections.#{inflection_type}.empty?, \"#{inflection_type} inflections should be empty after clear :#{inflection_type}\"
        ActiveSupport::Inflector.inflections.instance_variable_set :@#{inflection_type}, cached_values
      end
    "
  end

  def test_clear_all
    cached_values = ActiveSupport::Inflector.inflections.plurals, ActiveSupport::Inflector.inflections.singulars, ActiveSupport::Inflector.inflections.uncountables
    ActiveSupport::Inflector.inflections.clear :all
    assert ActiveSupport::Inflector.inflections.plurals.empty?
    assert ActiveSupport::Inflector.inflections.singulars.empty?
    assert ActiveSupport::Inflector.inflections.uncountables.empty?
    ActiveSupport::Inflector.inflections.instance_variable_set :@plurals, cached_values[0]
    ActiveSupport::Inflector.inflections.instance_variable_set :@singulars, cached_values[1]
    ActiveSupport::Inflector.inflections.instance_variable_set :@uncountables, cached_values[2]
  end

  def test_clear_with_default
    cached_values = ActiveSupport::Inflector.inflections.plurals, ActiveSupport::Inflector.inflections.singulars, ActiveSupport::Inflector.inflections.uncountables
    ActiveSupport::Inflector.inflections.clear
    assert ActiveSupport::Inflector.inflections.plurals.empty?
    assert ActiveSupport::Inflector.inflections.singulars.empty?
    assert ActiveSupport::Inflector.inflections.uncountables.empty?
    ActiveSupport::Inflector.inflections.instance_variable_set :@plurals, cached_values[0]
    ActiveSupport::Inflector.inflections.instance_variable_set :@singulars, cached_values[1]
    ActiveSupport::Inflector.inflections.instance_variable_set :@uncountables, cached_values[2]
  end

  Irregularities.each do |irregularity|
    singular, plural = *irregularity
    ActiveSupport::Inflector.inflections do |inflect|
      define_method("test_irregularity_between_#{singular}_and_#{plural}") do
        inflect.irregular(singular, plural)
        assert_equal singular, ActiveSupport::Inflector.singularize(plural)
        assert_equal plural, ActiveSupport::Inflector.pluralize(singular)
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
        singulars.reverse.each { |singular| inflect.singular(*singular) }
        plurals.reverse.each   { |plural|   inflect.plural(*plural) }
        inflect.uncountable(uncountables)

        assert_equal singulars, inflect.singulars
        assert_equal plurals, inflect.plurals
        assert_equal uncountables, inflect.uncountables
      end
    end
  end

  { :singulars => :singular, :plurals => :plural, :uncountables => :uncountable }.each do |scope, method|
    ActiveSupport::Inflector.inflections do |inflect|
      define_method("test_clear_inflections_with_#{scope}") do
        # save the inflections
        values = inflect.send(scope)

        # clear the inflections
        inflect.clear(scope)

        assert_equal [], inflect.send(scope)

        # restore the inflections
        if scope == :uncountables
          inflect.send(method, values)
        else
          values.reverse.each { |value| inflect.send(method, *value) }
        end

        assert_equal values, inflect.send(scope)
      end
    end
  end
end
