require File.dirname(__FILE__) + '/abstract_unit'

module Ace
  module Base
    class Case
    end
  end
end

class InflectorTest < Test::Unit::TestCase
  SingularToPlural = {
    "search"      => "searches",
    "switch"      => "switches",
    "fix"         => "fixes",
    "box"         => "boxes",
    "process"     => "processes",
    "address"     => "addresses",
    "case"        => "cases",
    "stack"       => "stacks",
    "wish"        => "wishes",
    "fish"        => "fish",

    "category"    => "categories",
    "query"       => "queries",
    "ability"     => "abilities",
    "agency"      => "agencies",
    "movie"       => "movies",

    "archive"     => "archives",

    "index"       => "indices",

    "wife"        => "wives",
    "safe"        => "saves",
    "half"        => "halves",

    "move"        => "moves",

    "salesperson" => "salespeople",
    "person"      => "people",

    "spokesman"   => "spokesmen",
    "man"         => "men",
    "woman"       => "women",

    "basis"       => "bases",
    "diagnosis"   => "diagnoses",

    "datum"       => "data",
    "medium"      => "media",
    "analysis"    => "analyses",

    "node_child"  => "node_children",
    "child"       => "children",

    "experience"  => "experiences",
    "day"         => "days",

    "comment"     => "comments",
    "foobar"      => "foobars",
    "newsletter"  => "newsletters",

    "old_news"    => "old_news",
    "news"        => "news",

    "series"      => "series",
    "species"     => "species",

    "quiz"        => "quizzes",

    "perspective" => "perspectives",

    "ox"          => "oxen",
    "photo"       => "photos",
    "buffalo"     => "buffaloes",
    "tomato"      => "tomatoes",
    "dwarf"       => "dwarves",
    "elf"         => "elves",
    "information" => "information",
    "equipment"   => "equipment",
    "bus"         => "buses",
    "status"      => "statuses",
    "status_code" => "status_codes",
    "mouse"       => "mice",

    "louse"       => "lice",
    "house"       => "houses",
    "octopus"     => "octopi",
    "virus"       => "viri",
    "alias"       => "aliases",
    "portfolio"   => "portfolios",

    "vertex"      => "vertices",
    "matrix"      => "matrices",

    "axis"        => "axes",
    "testis"      => "testes",
    "crisis"      => "crises",

    "rice"        => "rice",
    "shoe"        => "shoes",

    "horse"       => "horses",
    "prize"       => "prizes",
    "edge"        => "edges"
  }

  CamelToUnderscore = {
    "Product"               => "product",
    "SpecialGuest"          => "special_guest",
    "ApplicationController" => "application_controller",
    "Area51Controller"      => "area51_controller"
  }

  UnderscoreToLowerCamel = {
    "product"                => "product",
    "special_guest"          => "specialGuest",
    "application_controller" => "applicationController",
    "area51_controller"      => "area51Controller"
  }

  CamelToUnderscoreWithoutReverse = {
    "HTMLTidy"              => "html_tidy",
    "HTMLTidyGenerator"     => "html_tidy_generator",
    "FreeBSD"               => "free_bsd",
    "HTML"                  => "html",
  }

  CamelWithModuleToUnderscoreWithSlash = {
    "Admin::Product" => "admin/product",
    "Users::Commission::Department" => "users/commission/department",
    "UsersSection::CommissionDepartment" => "users_section/commission_department",
  }

  ClassNameToForeignKeyWithUnderscore = {
    "Person" => "person_id",
    "MyApplication::Billing::Account" => "account_id"
  }

  ClassNameToForeignKeyWithoutUnderscore = {
    "Person" => "personid",
    "MyApplication::Billing::Account" => "accountid"
  }

  ClassNameToTableName = {
    "PrimarySpokesman" => "primary_spokesmen",
    "NodeChild"        => "node_children"
  }

  UnderscoreToHuman = {
    "employee_salary" => "Employee salary",
    "employee_id"     => "Employee",
    "underground"     => "Underground"
  }

  MixtureToTitleCase = {
    'active_record'       => 'Active Record',
    'ActiveRecord'        => 'Active Record',
    'action web service'  => 'Action Web Service',
    'Action Web Service'  => 'Action Web Service',
    'Action web service'  => 'Action Web Service',
    'actionwebservice'    => 'Actionwebservice',
    'Actionwebservice'    => 'Actionwebservice'
  }

  OrdinalNumbers = {
    "0" => "0th",
    "1" => "1st",
    "2" => "2nd",
    "3" => "3rd",
    "4" => "4th",
    "5" => "5th",
    "6" => "6th",
    "7" => "7th",
    "8" => "8th",
    "9" => "9th",
    "10" => "10th",
    "11" => "11th",
    "12" => "12th",
    "13" => "13th",
    "14" => "14th",
    "20" => "20th",
    "21" => "21st",
    "22" => "22nd",
    "23" => "23rd",
    "24" => "24th",
    "100" => "100th",
    "101" => "101st",
    "102" => "102nd",
    "103" => "103rd",
    "104" => "104th",
    "110" => "110th",
    "111" => "111th",
    "112" => "112th",
    "113" => "113th",
    "1000" => "1000th",
    "1001" => "1001st"
  }

  UnderscoresToDashes = {
    "street"                => "street",
    "street_address"        => "street-address",
    "person_street_address" => "person-street-address"
  }

  Irregularities = {
    'person' => 'people',
    'man'    => 'men',
    'child'  => 'children',
    'sex'    => 'sexes',
    'move'   => 'moves',
  }

  def test_pluralize_plurals
    assert_equal "plurals", Inflector.pluralize("plurals")
    assert_equal "Plurals", Inflector.pluralize("Plurals")
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_pluralize_#{singular}" do
      assert_equal(plural, Inflector.pluralize(singular))
      assert_equal(plural.capitalize, Inflector.pluralize(singular.capitalize))
    end
  end

  SingularToPlural.each do |singular, plural|
    define_method "test_singularize_#{plural}" do
      assert_equal(singular, Inflector.singularize(plural))
      assert_equal(singular.capitalize, Inflector.singularize(plural.capitalize))
    end
  end

  MixtureToTitleCase.each do |before, titleized|
    define_method "test_titleize_#{before}" do
      assert_equal(titleized, Inflector.titleize(before))
    end
  end

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, Inflector.camelize(underscore))
    end
  end

  def test_underscore
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(underscore, Inflector.underscore(camel))
    end
    CamelToUnderscoreWithoutReverse.each do |camel, underscore|
      assert_equal(underscore, Inflector.underscore(camel))
    end
  end

  def test_camelize_with_module
    CamelWithModuleToUnderscoreWithSlash.each do |camel, underscore|
      assert_equal(camel, Inflector.camelize(underscore))
    end
  end

  def test_underscore_with_slashes
    CamelWithModuleToUnderscoreWithSlash.each do |camel, underscore|
      assert_equal(underscore, Inflector.underscore(camel))
    end
  end

  def test_demodulize
    assert_equal "Account", Inflector.demodulize("MyApplication::Billing::Account")
  end

  def test_foreign_key
    ClassNameToForeignKeyWithUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, Inflector.foreign_key(klass))
    end

    ClassNameToForeignKeyWithoutUnderscore.each do |klass, foreign_key|
      assert_equal(foreign_key, Inflector.foreign_key(klass, false))
    end
  end

  def test_tableize
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(table_name, Inflector.tableize(class_name))
    end
  end

  def test_classify
    ClassNameToTableName.each do |class_name, table_name|
      assert_equal(class_name, Inflector.classify(table_name))
    end
  end

  def test_classify_with_symbol
    assert_nothing_raised do
      assert_equal 'FooBar', Inflector.classify(:foo_bar)
    end
  end

  def test_classify_with_leading_schema_name
    assert_equal 'FooBar', Inflector.classify('schema.foo_bar')
  end

  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human, Inflector.humanize(underscore))
    end
  end

  def test_constantize
    assert_nothing_raised { assert_equal Ace::Base::Case, Inflector.constantize("Ace::Base::Case") }
    assert_nothing_raised { assert_equal Ace::Base::Case, Inflector.constantize("::Ace::Base::Case") }
    assert_nothing_raised { assert_equal InflectorTest, Inflector.constantize("InflectorTest") }
    assert_nothing_raised { assert_equal InflectorTest, Inflector.constantize("::InflectorTest") }
    assert_raises(NameError) { Inflector.constantize("UnknownClass") }
    assert_raises(NameError) { Inflector.constantize("An invalid string") }
    assert_raises(NameError) { Inflector.constantize("InvalidClass\n") }
  end

  def test_constantize_doesnt_look_in_parent
    assert_raises(NameError) { Inflector.constantize("Ace::Base::InflectorTest") }
  end

  def test_ordinal
    OrdinalNumbers.each do |number, ordinalized|
      assert_equal(ordinalized, Inflector.ordinalize(number))
    end
  end

  def test_dasherize
    UnderscoresToDashes.each do |underscored, dasherized|
      assert_equal(dasherized, Inflector.dasherize(underscored))
    end
  end

  def test_underscore_as_reverse_of_dasherize
    UnderscoresToDashes.each do |underscored, dasherized|
      assert_equal(underscored, Inflector.underscore(Inflector.dasherize(underscored)))
    end
  end

  def test_underscore_to_lower_camel
    UnderscoreToLowerCamel.each do |underscored, lower_camel|
      assert_equal(lower_camel, Inflector.camelize(underscored, false))
    end
  end

  Irregularities.each do |irregularity|
    singular, plural = *irregularity
    Inflector.inflections do |inflect|
      define_method("test_irregularity_between_#{singular}_and_#{plural}") do
        inflect.irregular(singular, plural)
        assert_equal singular, Inflector.singularize(plural)
        assert_equal plural, Inflector.pluralize(singular)
      end
    end
  end

  [ :all, [] ].each do |scope|
    Inflector.inflections do |inflect|
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
    Inflector.inflections do |inflect|
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
