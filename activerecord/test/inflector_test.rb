require 'abstract_unit'

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

    "category"    => "categories",
    "query"       => "queries",
    "ability"     => "abilities",
    "agency"      => "agencies",
    "movie"       => "movies",

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

    "node_child"  => "node_children",
    "child"       => "children",

    "experience"  => "experiences",
    "day"         => "days",

    "comment"     => "comments",
    "foobar"      => "foobars"
  }

  CamelToUnderscore = {
    "Product"                       => "product",
    "SpecialGuest"                  => "special_guest",
    "AbstractApplicationController" => "abstract_application_controller"
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

  def test_pluralize
    SingularToPlural.each do |singular, plural|
      assert_equal(plural, Inflector.pluralize(singular))
    end

    assert_equal("plurals", Inflector.pluralize("plurals"))
  end

  def test_singularize
    SingularToPlural.each do |singular, plural|
      assert_equal(singular, Inflector.singularize(plural))
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
end