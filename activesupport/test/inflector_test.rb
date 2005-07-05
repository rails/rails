require 'test/unit'
require File.dirname(__FILE__) + '/../lib/active_support/inflector'

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

    "wife"        => "wives",
    "safe"        => "saves",
    "half"        => "halves",

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

    "perspective" => "perspectives",
    
    "ox" => "oxen",
    "photo" => "photos",
    "buffalo" => "buffaloes",
    "tomato" => "tomatoes",
    "dwarf" => "dwarves",
    "elf" => "elves",
    "information" => "information",
    "equipment" => "equipment",
    "bus" => "buses",
    "mouse" => "mice",

    "louse" => "lice",
    "house" => "houses",
    "octopus" => "octopi",
    "virus" => "viri",
    "alias" => "aliases",
    "portfolio" => "portfolios",
    
    "vertex" => "vertices",
    "matrix" => "matrices",
    
    "axis" => "axes",
    "testis" => "testes",
    "crisis" => "crises",
    
    "rice" => "rice",
    "shoe" => "shoes",
    
    "horse" => "horses",
    "prize" => "prizes",
    "edge" => "edges"
  }

  CamelToUnderscore = {
    "Product"               => "product",
    "SpecialGuest"          => "special_guest",
    "ApplicationController" => "application_controller",
    "Area51Controller"      => "area51_controller"
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
    "underground"     => "Underground"
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

  def test_camelize
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(camel, Inflector.camelize(underscore))
    end
  end

  def test_underscore
    CamelToUnderscore.each do |camel, underscore|
      assert_equal(underscore, Inflector.underscore(camel))
    end
    
    assert_equal "html_tidy", Inflector.underscore("HTMLTidy")
    assert_equal "html_tidy_generator", Inflector.underscore("HTMLTidyGenerator")
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
  
  def test_humanize
    UnderscoreToHuman.each do |underscore, human|
      assert_equal(human, Inflector.humanize(underscore))
    end
  end
  
  def test_constantize
    assert_equal Ace::Base::Case, Inflector.constantize("Ace::Base::Case")
    assert_equal InflectorTest, Inflector.constantize("InflectorTest")
    assert_raises(NameError) { Inflector.constantize("UnknownClass") }
  end
end