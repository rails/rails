require "cases/helper"

module ActiveRecord
  class DynamicFinderMatchTest < ActiveRecord::TestCase
    def test_find_or_create_by
      match = DynamicFinderMatch.match("find_or_create_by_age_and_sex_and_location")
      assert_not_nil match
      assert !match.finder?
      assert match.instantiator?
      assert_equal :first, match.finder
      assert_equal :create, match.instantiator
      assert_equal %w(age sex location), match.attribute_names
    end

    def test_find_or_initialize_by
      match = DynamicFinderMatch.match("find_or_initialize_by_age_and_sex_and_location")
      assert_not_nil match
      assert !match.finder?
      assert match.instantiator?
      assert_equal :first, match.finder
      assert_equal :new, match.instantiator
      assert_equal %w(age sex location), match.attribute_names
    end

    def test_find_no_match
      assert_nil DynamicFinderMatch.match("not_a_finder")
    end

    def find_by_bang
      match = DynamicFinderMatch.match("find_by_age_and_sex_and_location!")
      assert_not_nil match
      assert match.finder?
      assert match.bang?
      assert_equal :first, match.finder
      assert_equal %w(age sex location), match.attribute_names
    end

    def test_find_by
      match = DynamicFinderMatch.match("find_by_age_and_sex_and_location")
      assert_not_nil match
      assert match.finder?
      assert_equal :first, match.finder
      assert_equal %w(age sex location), match.attribute_names
    end

    def test_find_by_with_symbol
      m = DynamicFinderMatch.match(:find_by_foo)
      assert_equal :first, m.finder
      assert_equal %w{ foo }, m.attribute_names
    end

    def test_find_all_by_with_symbol
      m = DynamicFinderMatch.match(:find_all_by_foo)
      assert_equal :all, m.finder
      assert_equal %w{ foo }, m.attribute_names
    end

    def test_find_all_by
      match = DynamicFinderMatch.match("find_all_by_age_and_sex_and_location")
      assert_not_nil match
      assert match.finder?
      assert_equal :all, match.finder
      assert_equal %w(age sex location), match.attribute_names
    end

    def test_find_last_by
      m = DynamicFinderMatch.match(:find_last_by_foo)
      assert_equal :last, m.finder
      assert_equal %w{ foo }, m.attribute_names
    end

    def test_find_by!
      m = DynamicFinderMatch.match(:find_by_foo!)
      assert_equal :first, m.finder
      assert m.bang?, 'should be banging'
      assert_equal %w{ foo }, m.attribute_names
    end

    def test_find_or_create
      m = DynamicFinderMatch.match(:find_or_create_by_foo)
      assert_equal :first, m.finder
      assert_equal %w{ foo }, m.attribute_names
      assert_equal :create, m.instantiator
    end

    def test_find_or_create!
      m = DynamicFinderMatch.match(:find_or_create_by_foo!)
      assert_equal :first, m.finder
      assert m.bang?, 'should be banging'
      assert_equal %w{ foo }, m.attribute_names
      assert_equal :create, m.instantiator
    end

    def test_find_or_initialize
      m = DynamicFinderMatch.match(:find_or_initialize_by_foo)
      assert_equal :first, m.finder
      assert_equal %w{ foo }, m.attribute_names
      assert_equal :new, m.instantiator
    end

    def test_garbage
      assert !DynamicFinderMatch.match(:fooo), 'should be false'
      assert !DynamicFinderMatch.match(:find_by), 'should be false'
    end
  end
end
