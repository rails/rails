require "abstract_unit"

module PeopleHelper
  def title(text)
    content_tag(:h1, text)
  end

  def homepage_path
    people_path
  end

  def homepage_url
    people_url
  end

  def link_to_person(person)
    link_to person.name, person
  end
end

class PeopleHelperTest < ActionView::TestCase
  def test_title
    assert_equal "<h1>Ruby on Rails</h1>", title("Ruby on Rails")
  end

  def test_homepage_path
    with_test_route_set do
      assert_equal "/people", homepage_path
    end
  end

  def test_homepage_url
    with_test_route_set do
      assert_equal "http://test.host/people", homepage_url
    end
  end

  def test_link_to_person
    with_test_route_set do
      person = Struct.new(:name) {
        extend ActiveModel::Naming
        def to_model; self; end
        def persisted?; true; end
        def self.name; "Minitest::Mock"; end
      }.new "David"

      the_model = nil
      extend Module.new {
        define_method(:minitest_mock_path) { |model, *args|
          the_model = model
          "/people/1"
        }
      }
      assert_equal '<a href="/people/1">David</a>', link_to_person(person)
      assert_equal person, the_model
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do
          get "people", to: "people#index", as: :people
        end
        yield
      end
    end
end

class CrazyHelperTest < ActionView::TestCase
  tests PeopleHelper

  def test_helper_class_can_be_set_manually_not_just_inferred
    assert_equal PeopleHelper, self.class.helper_class
  end
end

class CrazySymbolHelperTest < ActionView::TestCase
  tests :people

  def test_set_helper_class_using_symbol
    assert_equal PeopleHelper, self.class.helper_class
  end
end

class CrazyStringHelperTest < ActionView::TestCase
  tests "people"

  def test_set_helper_class_using_string
    assert_equal PeopleHelper, self.class.helper_class
  end
end
