require 'abstract_unit'

class InflectorTest < Test::Unit::TestCase
  SingularToPlural = {
    "search"      => "searches",
    "switch"      => "switches",
    "fix"         => "fixes",
    "box"         => "boxes",
    "process"     => "processes",
    "address"     => "addresses",

    "category"    => "categories",
    "query"       => "queries",
    "ability"     => "abilities",
    "agency"      => "agencies",

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

    "comment"     => "comments",
    "foobar"      => "foobars"
  }

  def test_pluralize
    SingularToPlural.each do |(singular, plural)|
      assert_equal(plural, Inflector.pluralize(singular))
    end

    assert_equal("plurals", Inflector.pluralize("plurals"))
  end

  def test_singularize
    SingularToPlural.each do |(singular, plural)|
      assert_equal(singular, Inflector.singularize(plural))
    end
  end
end
