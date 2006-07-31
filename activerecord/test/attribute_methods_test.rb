require 'abstract_unit'

class AttributeMethodsTest < Test::Unit::TestCase
  def setup
    @target = Class.new(ActiveRecord::Base)
    @target.table_name = 'topics'
  end

  def test_match_attribute_method_query_returns_match_data
    assert_not_nil md = @target.match_attribute_method?('title=')
    assert_equal 'title', md.pre_match
    assert_equal ['='], md.captures
  end

  def test_declared_attribute_method_affects_respond_to_and_method_missing
    topic = @target.new(:title => 'Budget')
    assert topic.respond_to?('title')
    assert_equal 'Budget', topic.title
    assert !topic.respond_to?('title_hello_world')
    assert_raise(NoMethodError) { topic.title_hello_world }

    @target.class_eval "def attribute_hello_world(*args) args end"
    @target.attribute_method_suffix '_hello_world'

    assert topic.respond_to?('title_hello_world')
    assert_equal ['title'], topic.title_hello_world
    assert_equal ['title', 'a'], topic.title_hello_world('a')
    assert_equal ['title', 1, 2, 3], topic.title_hello_world(1, 2, 3)
  end
end
