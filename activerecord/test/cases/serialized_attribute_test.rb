require "cases/helper"
require "models/topic"
require "models/reply"
require "models/person"
require "models/traffic_light"
require "models/post"
require "bcrypt"

class SerializedAttributeTest < ActiveRecord::TestCase
  fixtures :topics, :posts

  MyObject = Struct.new :attribute1, :attribute2

  teardown do
    Topic.serialize("content")
  end

  def test_serialize_does_not_eagerly_load_columns
    Topic.reset_column_information
    assert_no_queries do
      Topic.serialize(:content)
    end
  end

  def test_serialized_attribute
    Topic.serialize("content", MyObject)

    myobj = MyObject.new("value1", "value2")
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_in_base_class
    Topic.serialize("content", Hash)

    hash = { "content1" => "value1", "content2" => "value2" }
    important_topic = ImportantTopic.create("content" => hash)
    assert_equal(hash, important_topic.content)

    important_topic.reload
    assert_equal(hash, important_topic.content)
  end

  def test_serialized_attributes_from_database_on_subclass
    Topic.serialize :content, Hash

    t = Reply.new(content: { foo: :bar })
    assert_equal({ foo: :bar }, t.content)
    t.save!
    t = Reply.last
    assert_equal({ foo: :bar }, t.content)
  end

  def test_serialized_attribute_calling_dup_method
    Topic.serialize :content, JSON

    orig = Topic.new(content: { foo: :bar })
    clone = orig.dup
    assert_equal(orig.content, clone.content)
  end

  def test_serialized_json_attribute_returns_unserialized_value
    Topic.serialize :content, JSON
    my_post = posts(:welcome)

    t = Topic.new(content: my_post)
    t.save!
    t.reload

    assert_instance_of(Hash, t.content)
    assert_equal(my_post.id, t.content["id"])
    assert_equal(my_post.title, t.content["title"])
  end

  def test_json_read_legacy_null
    Topic.serialize :content, JSON

    # Force a row to have a JSON "null" instead of a database NULL (this is how
    # null values are saved on 4.1 and before)
    id = Topic.connection.insert "INSERT INTO topics (content) VALUES('null')"
    t = Topic.find(id)

    assert_nil t.content
  end

  def test_json_read_db_null
    Topic.serialize :content, JSON

    # Force a row to have a database NULL instead of a JSON "null"
    id = Topic.connection.insert "INSERT INTO topics (content) VALUES(NULL)"
    t = Topic.find(id)

    assert_nil t.content
  end

  def test_serialized_attribute_declared_in_subclass
    hash = { "important1" => "value1", "important2" => "value2" }
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
    assert Topic.new(content: nil).save
    assert_equal 1, Topic.where(content: nil).count
  end

  def test_nil_not_serialized_with_class_constraint
    Topic.serialize :content, Hash
    assert Topic.new(content: nil).save
    assert_equal 1, Topic.where(content: nil).count
  end

  def test_serialized_attribute_should_raise_exception_on_assignment_with_wrong_type
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) do
      Topic.new(content: "string")
    end
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new("value1", "value2")
    topic = Topic.new(content: myobj)
    assert topic.save
    Topic.serialize(:content, Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  end

  def test_serialized_attribute_with_class_constraint
    settings = { "color" => "blue" }
    Topic.serialize(:content, Hash)
    topic = Topic.new(content: settings)
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
    topic = Topic.new(content: true)
    assert topic.save
    topic = topic.reload
    assert_equal topic.content, true
  end

  def test_serialized_boolean_value_false
    topic = Topic.new(content: false)
    assert topic.save
    topic = topic.reload
    assert_equal topic.content, false
  end

  def test_serialize_with_coder
    some_class = Struct.new(:foo) do
      def self.dump(value)
        value.foo
      end

      def self.load(value)
        new(value)
      end
    end

    Topic.serialize(:content, some_class)
    topic = Topic.new(content: some_class.new("my value"))
    topic.save!
    topic.reload
    assert_kind_of some_class, topic.content
    assert_equal topic.content, some_class.new("my value")
  end

  def test_serialize_attribute_via_select_method_when_time_zone_available
    with_timezone_config aware_attributes: true do
      Topic.serialize(:content, MyObject)

      myobj = MyObject.new("value1", "value2")
      topic = Topic.create(content: myobj)

      assert_equal(myobj, Topic.select(:content).find(topic.id).content)
      assert_raise(ActiveModel::MissingAttributeError) { Topic.select(:id).find(topic.id).content }
    end
  end

  def test_serialize_attribute_can_be_serialized_in_an_integer_column
    insures = ["life"]
    person = SerializedPerson.new(first_name: "David", insures: insures)
    assert person.save
    person = person.reload
    assert_equal(insures, person.insures)
  end

  def test_regression_serialized_default_on_text_column_with_null_false
    light = TrafficLight.new
    assert_equal [], light.state
    assert_equal [], light.long_state
  end

  def test_serialized_column_should_unserialize_after_update_column
    t = Topic.create(content: "first")
    assert_equal("first", t.content)

    t.update_column(:content, ["second"])
    assert_equal(["second"], t.content)
    assert_equal(["second"], t.reload.content)
  end

  def test_serialized_column_should_unserialize_after_update_attribute
    t = Topic.create(content: "first")
    assert_equal("first", t.content)

    t.update_attribute(:content, "second")
    assert_equal("second", t.content)
    assert_equal("second", t.reload.content)
  end

  def test_nil_is_not_changed_when_serialized_with_a_class
    Topic.serialize(:content, Array)

    topic = Topic.new(content: nil)

    assert_not topic.content_changed?
  end

  def test_classes_without_no_arg_constructors_are_not_supported
    assert_raises(ArgumentError) do
      Topic.serialize(:content, Regexp)
    end
  end

  def test_newly_emptied_serialized_hash_is_changed
    Topic.serialize(:content, Hash)
    topic = Topic.create(content: { "things" => "stuff" })
    topic.content.delete("things")
    topic.save!
    topic.reload

    assert_equal({}, topic.content)
  end

  def test_values_cast_from_nil_are_persisted_as_nil
    # This is required to fulfil the following contract, which must be universally
    # true in Active Record:
    #
    # model.attribute = value
    # assert_equal model.attribute, model.tap(&:save).reload.attribute
    Topic.serialize(:content, Hash)
    topic = Topic.create!(content: {})
    topic2 = Topic.create!(content: nil)

    assert_equal [topic, topic2], Topic.where(content: nil)
  end

  def test_nil_is_always_persisted_as_null
    Topic.serialize(:content, Hash)

    topic = Topic.create!(content: { foo: "bar" })
    topic.update_attribute :content, nil
    assert_equal [topic], Topic.where(content: nil)
  end

  def test_mutation_detection_does_not_double_serialize
    coder = Object.new
    def coder.dump(value)
      return if value.nil?
      value + " encoded"
    end
    def coder.load(value)
      return if value.nil?
      value.gsub(" encoded", "")
    end
    type = Class.new(ActiveModel::Type::Value) do
      include ActiveModel::Type::Helpers::Mutable

      def serialize(value)
        return if value.nil?
        value + " serialized"
      end

      def deserialize(value)
        return if value.nil?
        value.gsub(" serialized", "")
      end
    end.new
    model = Class.new(Topic) do
      attribute :foo, type
      serialize :foo, coder
    end

    topic = model.create!(foo: "bar")
    topic.foo
    refute topic.changed?
  end
end
