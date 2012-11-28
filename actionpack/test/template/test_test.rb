require 'abstract_unit'

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
      person = mock(:name => "David")
      person.class.extend ActiveModel::Naming
      expects(:mocha_mock_path).with(person).returns("/people/1")
      assert_equal '<a href="/people/1">David</a>', link_to_person(person)
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do
          get 'people', :to => 'people#index', :as => :people
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
  tests 'people'

  def test_set_helper_class_using_string
    assert_equal PeopleHelper, self.class.helper_class
  end
end

describe PeopleHelper do
  it "resolves the right helper_class" do
    assert_equal PeopleHelper, self.class.helper_class
  end
end

describe PeopleHelper, :helper_class do
  it "resolves the right helper_class" do
    assert_equal PeopleHelper, self.class.helper_class
  end
end

describe PeopleHelper do
  describe "even while nested" do
    it "resolves the right helper_class" do
      assert_equal PeopleHelper, self.class.helper_class
    end
  end
end

describe PeopleHelper, :helper_class do
  describe "even while nested" do
    it "resolves the right helper_class" do
      assert_equal PeopleHelper, self.class.helper_class
    end
  end
end

describe "PeopleHelper" do
  it "resolves the right helper_class" do
    assert_equal PeopleHelper, self.class.helper_class
  end
end

describe "PeopleHelperTest" do
  it "resolves the right helper_class" do
    assert_equal PeopleHelper, self.class.helper_class
  end
end

describe "PeopleHelper" do
  describe "even while nested" do
    it "resolves the right helper_class" do
      assert_equal PeopleHelper, self.class.helper_class
    end
  end
end

describe "PeopleHelperTest" do
  describe "even while nested" do
    it "resolves the right helper_class" do
      assert_equal PeopleHelper, self.class.helper_class
    end
  end
end
