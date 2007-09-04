require 'abstract_unit'
require 'fixtures/topic'

class AttributeMethodsTest < Test::Unit::TestCase
  def setup
    @old_suffixes = ActiveRecord::Base.send(:attribute_method_suffixes).dup
    @target = Class.new(ActiveRecord::Base)
    @target.table_name = 'topics'
  end

  def teardown
    ActiveRecord::Base.send(:attribute_method_suffixes).clear
    ActiveRecord::Base.attribute_method_suffix *@old_suffixes
  end


  def test_match_attribute_method_query_returns_match_data
    assert_not_nil md = @target.match_attribute_method?('title=')
    assert_equal 'title', md.pre_match
    assert_equal ['='], md.captures

    %w(_hello_world ist! _maybe?).each do |suffix|
      @target.class_eval "def attribute#{suffix}(*args) args end"
      @target.attribute_method_suffix suffix

      assert_not_nil md = @target.match_attribute_method?("title#{suffix}")
      assert_equal 'title', md.pre_match
      assert_equal [suffix], md.captures
    end
  end

  def test_declared_attribute_method_affects_respond_to_and_method_missing
    topic = @target.new(:title => 'Budget')
    assert topic.respond_to?('title')
    assert_equal 'Budget', topic.title
    assert !topic.respond_to?('title_hello_world')
    assert_raise(NoMethodError) { topic.title_hello_world }

    %w(_hello_world _it! _candidate= able?).each do |suffix|
      @target.class_eval "def attribute#{suffix}(*args) args end"
      @target.attribute_method_suffix suffix

      meth = "title#{suffix}"
      assert topic.respond_to?(meth)
      assert_equal ['title'], topic.send(meth)
      assert_equal ['title', 'a'], topic.send(meth, 'a')
      assert_equal ['title', 1, 2, 3], topic.send(meth, 1, 2, 3)
    end
  end
  
  def test_should_unserialize_attributes_for_frozen_records
    myobj = {:value1 => :value2}
    topic = Topic.create("content" => myobj)
    topic.freeze
    assert_equal myobj, topic.content
    
  end
end
