require 'abstract_unit'
require 'fixtures/topic'

class AttributeMethodsTest < Test::Unit::TestCase
  fixtures :topics
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
  
  def test_kernel_methods_not_implemented_in_activerecord
    %w(test name display y).each do |method|
      assert_equal false, ActiveRecord::Base.instance_method_already_implemented?(method), "##{method} is defined"
    end
  end
  
  def test_primary_key_implemented
    assert_equal true, Class.new(ActiveRecord::Base).instance_method_already_implemented?('id')
  end
  
  def test_defined_kernel_methods_implemented_in_model
    %w(test name display y).each do |method|
      klass = Class.new ActiveRecord::Base
      klass.class_eval "def #{method}() 'defined #{method}' end"
      assert_equal true, klass.instance_method_already_implemented?(method), "##{method} is not defined"
    end
  end
  
  def test_defined_kernel_methods_implemented_in_model_abstract_subclass
    %w(test name display y).each do |method|
      abstract = Class.new ActiveRecord::Base
      abstract.class_eval "def #{method}() 'defined #{method}' end"
      abstract.abstract_class = true
      klass = Class.new abstract
      assert_equal true, klass.instance_method_already_implemented?(method), "##{method} is not defined"
    end
  end
  
  def test_raises_dangerous_attribute_error_when_defining_activerecord_method_in_model
    %w(save create_or_update).each do |method|
      klass = Class.new ActiveRecord::Base
      klass.class_eval "def #{method}() 'defined #{method}' end"
      assert_raises ActiveRecord::DangerousAttributeError do
        klass.instance_method_already_implemented?(method)
      end
    end
  end

  def test_only_time_related_columns_are_meant_to_be_cached_by_default
    expected = %w(datetime timestamp time date).sort
    assert_equal expected, ActiveRecord::Base.attribute_types_cached_by_default.map(&:to_s).sort
end

  def test_declaring_attributes_as_cached_adds_them_to_the_attributes_cached_by_default
    default_attributes = Topic.cached_attributes
    Topic.cache_attributes :replies_count
    expected = default_attributes + ["replies_count"]
    assert_equal expected.sort, Topic.cached_attributes.sort
    Topic.instance_variable_set "@cached_attributes", nil
  end

  def test_time_related_columns_are_actually_cached
    column_types = %w(datetime timestamp time date).map(&:to_sym)
    column_names = Topic.columns.select{|c| column_types.include?(c.type) }.map(&:name)

    assert_equal column_names.sort, Topic.cached_attributes.sort
    assert_equal time_related_columns_on_topic.sort, Topic.cached_attributes.sort
  end

  def test_accessing_cached_attributes_caches_the_converted_values_and_nothing_else
    t = topics(:first)
    cache = t.instance_variable_get "@attributes_cache"

    assert_not_nil cache
    assert cache.empty?

    all_columns = Topic.columns.map(&:name)
    cached_columns = time_related_columns_on_topic
    uncached_columns =  all_columns - cached_columns

    all_columns.each do |attr_name|
      attribute_gets_cached = Topic.cache_attribute?(attr_name)
      val = t.send attr_name unless attr_name == "type"
      if attribute_gets_cached
        assert cached_columns.include?(attr_name)
        assert_equal val, cache[attr_name]
      else
        assert uncached_columns.include?(attr_name)
        assert !cache.include?(attr_name)
      end
    end
  end

  private
  def time_related_columns_on_topic
    Topic.columns.select{|c| [:time, :date, :datetime, :timestamp].include?(c.type)}.map(&:name)
  end
end
