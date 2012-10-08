require "cases/helper"
require 'models/topic'
require 'bcrypt'

class SerializedAttributeTest < ActiveRecord::TestCase
  fixtures :topics

  MyObject = Struct.new :attribute1, :attribute2

  def teardown
    super
    Topic.serialize("content")
  end

  def test_list_of_serialized_attributes
    assert_equal %w(content), Topic.serialized_attributes.keys
  end

  def test_serialized_attributes_are_class_level_settings
    topic = Topic.new
    assert_raise(NoMethodError) { topic.serialized_attributes = [] }
    assert_deprecated { topic.serialized_attributes }
  end

  def test_serialized_attribute
    Topic.serialize("content", MyObject)

    myobj = MyObject.new('value1', 'value2')
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_init_with
    topic = Topic.allocate
    topic.init_with('attributes' => { 'content' => '--- foo' })
    assert_equal 'foo', topic.content
  end

  def test_serialized_attribute_in_base_class
    Topic.serialize("content", Hash)

    hash = { 'content1' => 'value1', 'content2' => 'value2' }
    important_topic = ImportantTopic.create("content" => hash)
    assert_equal(hash, important_topic.content)

    important_topic.reload
    assert_equal(hash, important_topic.content)
  end

  # This test was added to fix GH #4004. Obviously the value returned
  # is not really the value 'before type cast' so we should maybe think
  # about changing that in the future.
  def test_serialized_attribute_before_type_cast_returns_unserialized_value
    Topic.serialize :content, Hash

    t = Topic.new(:content => { :foo => :bar })
    assert_equal({ :foo => :bar }, t.content_before_type_cast)
    t.save!
    t.reload
    assert_equal({ :foo => :bar }, t.content_before_type_cast)
  end

  def test_serialized_attribute_calling_dup_method
    Topic.serialize :content, JSON

    t = Topic.new(:content => { :foo => :bar }).dup
    assert_equal({ :foo => :bar }, t.content_before_type_cast)
  end

  def test_serialized_attribute_declared_in_subclass
    hash = { 'important1' => 'value1', 'important2' => 'value2' }
    important_topic = ImportantTopic.create("important" => hash)
    assert_equal(hash, important_topic.important)

    important_topic.reload
    assert_equal(hash, important_topic.important)
    assert_equal(hash, important_topic.read_attribute(:important))
  end

  def test_serialized_time_attribute
    myobj = Time.local(2008,1,1,1,0)
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_string_attribute
    myobj = "Yes"
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_nil_serialized_attribute_without_class_constraint
    topic = Topic.new
    assert_nil topic.content
  end

  def test_nil_not_serialized_without_class_constraint
    assert Topic.new(:content => nil).save
    assert_equal 1, Topic.where(:content => nil).count
  end

  def test_nil_not_serialized_with_class_constraint
    Topic.serialize :content, Hash
    assert Topic.new(:content => nil).save
    assert_equal 1, Topic.where(:content => nil).count
  end

  def test_serialized_attribute_should_raise_exception_on_save_with_wrong_type
    Topic.serialize(:content, Hash)
    topic = Topic.new(:content => "string")
    assert_raise(ActiveRecord::SerializationTypeMismatch) { topic.save }
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new('value1', 'value2')
    topic = Topic.new(:content => myobj)
    assert topic.save
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  end

  def test_serialized_attribute_with_class_constraint
    settings = { "color" => "blue" }
    Topic.serialize(:content, Hash)
    topic = Topic.new(:content => settings)
    assert topic.save
    assert_equal(settings, Topic.find(topic.id).content)
  end

  def test_serialized_default_class
    Topic.serialize(:content, Hash)
    topic = Topic.new
    assert_equal Hash, topic.content.class
    assert_equal Hash, topic.read_attribute(:content).class
    topic.content["beer"] = "MadridRb"
    assert topic.save
    topic.reload
    assert_equal Hash, topic.content.class
    assert_equal "MadridRb", topic.content["beer"]
  end

  def test_serialized_no_default_class_for_object
    topic = Topic.new
    assert_nil topic.content
  end

  def test_serialized_boolean_value_true
    topic = Topic.new(:content => true)
    assert topic.save
    topic = topic.reload
    assert_equal topic.content, true
  end

  def test_serialized_boolean_value_false
    topic = Topic.new(:content => false)
    assert topic.save
    topic = topic.reload
    assert_equal topic.content, false
  end

  def test_serialize_with_coder
    coder = Class.new {
      # Identity
      def load(thing)
        thing
      end

      # base 64
      def dump(thing)
        [thing].pack('m')
      end
    }.new

    Topic.serialize(:content, coder)
    s = 'hello world'
    topic = Topic.new(:content => s)
    assert topic.save
    topic = topic.reload
    assert_equal [s].pack('m'), topic.content
  end

  def test_serialize_with_bcrypt_coder
    crypt_coder = Class.new {
      def load(thing)
        return unless thing
        BCrypt::Password.new thing
      end

      def dump(thing)
        BCrypt::Password.create(thing).to_s
      end
    }.new

    Topic.serialize(:content, crypt_coder)
    password = 'password'
    topic = Topic.new(:content => password)
    assert topic.save
    topic = topic.reload
    assert_kind_of BCrypt::Password, topic.content
    assert_equal(true, topic.content == password, 'password should equal')
  end
end
