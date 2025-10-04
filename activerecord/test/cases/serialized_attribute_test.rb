# frozen_string_literal: true

require "cases/helper"
require "models/person"
require "models/traffic_light"
require "models/post"

class SerializedAttributeTest < ActiveRecord::TestCase
  def setup
    ActiveRecord.use_yaml_unsafe_load = true
    @yaml_column_permitted_classes_default = ActiveRecord.yaml_column_permitted_classes
  end

  def teardown
    Topic.serialize("content")
    ActiveRecord.yaml_column_permitted_classes = @yaml_column_permitted_classes_default
  end

  fixtures :topics, :posts

  MyObject = Struct.new :attribute1, :attribute2

  class Topic < ActiveRecord::Base
    serialize :content
  end

  class ImportantTopic < Topic
    serialize :important, type: Hash
  end

  class ClassifiedTopic < Topic
    serialize :important, type: Class
  end

  def test_serialize_does_not_eagerly_load_columns
    Topic.reset_column_information
    assert_no_queries do
      Topic.serialize(:content)
    end
  end

  def test_serialized_attribute
    Topic.serialize("content", type: MyObject)

    myobj = MyObject.new("value1", "value2")
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_on_alias_attribute
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      alias_attribute :object, :content
      serialize :object, type: MyObject
    end

    myobj = MyObject.new("value1", "value2")
    topic = klass.create!(object: myobj)
    assert_equal(myobj, topic.object)

    topic.reload
    assert_equal(myobj, topic.object)
  end

  def test_serialized_attribute_with_default
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      serialize(:content, type: Hash, default: { key: "value" })
    end

    t = klass.new
    assert_equal({ key: "value" }, t.content)
  end

  def test_serialized_attribute_on_custom_attribute_with_default
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      attribute :content, default: { key: "value" }
      serialize :content, type: Hash
    end

    t = klass.new
    assert_equal({ key: "value" }, t.content)
  end

  def test_serialized_attribute_in_base_class
    Topic.serialize("content", type: Hash)

    hash = { "content1" => "value1", "content2" => "value2" }
    important_topic = ImportantTopic.create("content" => hash)
    assert_equal(hash, important_topic.content)

    important_topic.reload
    assert_equal(hash, important_topic.content)
  end

  def test_serialized_attributes_from_database_on_subclass
    Topic.serialize :content, type: Hash

    t = ImportantTopic.new(content: { foo: :bar })
    assert_equal({ foo: :bar }, t.content)
    t.save!
    t = ImportantTopic.last
    assert_equal({ foo: :bar }, t.content)
  end

  def test_serialized_attribute_calling_dup_method
    Topic.serialize :content, coder: JSON

    orig = Topic.new(content: { foo: :bar })
    clone = orig.dup
    assert_equal(orig.content, clone.content)
  end

  def test_serialized_json_attribute_returns_unserialized_value
    Topic.serialize :content, coder: JSON
    my_post = posts(:welcome)

    t = Topic.new(content: my_post)
    t.save!
    t.reload

    assert_instance_of(Hash, t.content)
    assert_equal(my_post.id, t.content["id"])
    assert_equal(my_post.title, t.content["title"])
  end

  def test_json_read_legacy_null
    Topic.serialize :content, coder: JSON

    # Force a row to have a JSON "null" instead of a database NULL (this is how
    # null values are saved on 4.1 and before)
    id = Topic.lease_connection.insert "INSERT INTO topics (content) VALUES('null')"
    t = Topic.find(id)

    assert_nil t.content
  end

  def test_json_read_db_null
    Topic.serialize :content, coder: JSON

    # Force a row to have a database NULL instead of a JSON "null"
    id = Topic.lease_connection.insert "INSERT INTO topics (content) VALUES(NULL)"
    t = Topic.find(id)

    assert_nil t.content
  end

  def test_json_type_hash_default_value
    Topic.serialize :content, coder: JSON, type: Hash
    t = Topic.new
    assert_equal({}, t.content)
  end

  def test_json_symbolize_names_returns_symbolized_names
    Topic.serialize :content, coder: ActiveRecord::Coders::JSON.new(symbolize_names: true)
    my_post = posts(:welcome)

    t = Topic.new(content: my_post)
    t.save!
    t.reload

    assert_equal(t.content.deep_symbolize_keys, t.content)
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
    myobj = Time.local(2008, 1, 1, 1, 0)
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_string_attribute
    myobj = "Yes"
    topic = Topic.create("content" => myobj).reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_class_attribute
    ActiveRecord.yaml_column_permitted_classes += [Class]

    topic = ClassifiedTopic.create(important: Symbol).reload
    assert_equal(Symbol, topic.important)
    assert_not_empty ClassifiedTopic.where(important: Symbol)
  end

  def test_serialized_class_does_not_become_frozen
    ActiveRecord.yaml_column_permitted_classes += [Class]

    assert_not_predicate Symbol, :frozen?
    ClassifiedTopic.create(important: Symbol)
    assert_not_empty ClassifiedTopic.where(important: Symbol)
    assert_not_predicate Symbol, :frozen?
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
    Topic.serialize :content, type: Hash
    assert Topic.new(content: nil).save
    assert_equal 1, Topic.where(content: nil).count
  end

  def test_serialized_attribute_should_raise_exception_on_assignment_with_wrong_type
    Topic.serialize(:content, type: Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) do
      Topic.new(content: "string")
    end
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = MyObject.new("value1", "value2")
    topic = Topic.new(content: myobj)
    assert topic.save
    Topic.serialize(:content, type: Hash)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  end

  def test_serialized_attribute_with_class_constraint
    settings = { "color" => "blue" }
    Topic.serialize(:content, type: Hash)
    topic = Topic.new(content: settings)
    assert topic.save
    assert_equal(settings, Topic.find(topic.id).content)
  end

  def test_where_by_serialized_attribute_with_array
    settings = [ "color" => "green" ]
    Topic.serialize(:content, type: Array)
    topic = Topic.create!(content: settings)
    assert_equal topic, Topic.where(content: settings).take
  end

  def test_where_by_serialized_attribute_with_hash
    settings = { "color" => "green" }
    Topic.serialize(:content, type: Hash)
    topic = Topic.create!(content: settings)
    assert_equal topic, Topic.where(content: settings).take
  end

  def test_where_by_serialized_attribute_with_hash_in_array
    settings = { "color" => "green" }
    Topic.serialize(:content, type: Hash)
    topic = Topic.create!(content: settings)
    assert_equal topic, Topic.where(content: [settings, { "herring" => "red" }]).take
  end

  def test_serialized_default_class
    Topic.serialize(:content, type: Hash)
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
    assert_equal true, topic.content
  end

  def test_serialized_boolean_value_false
    topic = Topic.new(content: false)
    assert topic.save
    topic = topic.reload
    assert_equal false, topic.content
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

    Topic.serialize(:content, coder: some_class)
    topic = Topic.new(content: some_class.new("my value"))
    topic.save!
    topic.reload
    assert_kind_of some_class, topic.content
    assert_equal some_class.new("my value"), topic.content
  end

  def test_serialize_attribute_via_select_method_when_time_zone_available
    with_timezone_config aware_attributes: true do
      Topic.serialize(:content, type: MyObject)

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

  def test_unexpected_serialized_type
    Topic.serialize :content, type: Hash
    topic = Topic.create!(content: { zomg: true })

    Topic.serialize :content, type: Array

    topic.reload
    error = assert_raise(ActiveRecord::SerializationTypeMismatch) do
      topic.content
    end
    expected = "can't load `content`: was supposed to be a Array, but was a Hash. -- #{{ zomg: true }}"
    assert_equal expected, error.to_s
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
    Topic.serialize(:content, type: Array)

    topic = Topic.new(content: nil)

    assert_not_predicate topic, :content_changed?
  end

  def test_classes_without_no_arg_constructors_are_not_supported
    assert_raises(ArgumentError) do
      Topic.serialize(:content, type: Regexp)
    end
  end

  def test_newly_emptied_serialized_hash_is_changed
    Topic.serialize(:content, type: Hash)
    topic = Topic.create(content: { "things" => "stuff" })
    topic.content.delete("things")
    topic.save!
    topic.reload

    assert_equal({}, topic.content)
  end

  def test_is_not_changed_when_stored_blob
    Topic.serialize(:binary_content, type: Array)
    Topic.serialize(:content, type: Array)

    value = %w(Fée)
    model = Topic.create!(binary_content: value, content: value)
    model.reload

    model.binary_content = value
    assert_not_predicate model, :binary_content_changed?

    model.content = value
    assert_not_predicate model, :content_changed?
  end

  class FrozenCoder < ActiveRecord::Coders::YAMLColumn
    def dump(obj)
      super&.freeze
    end
  end

  def test_is_not_changed_when_stored_in_blob_frozen_payload
    Topic.serialize(:binary_content, coder: FrozenCoder.new(:binary_content, Array))
    Topic.serialize(:content, coder: FrozenCoder.new(:content, Array))

    value = %w(Fée)
    model = Topic.create!(binary_content: value, content: value)
    model.reload

    model.content = value
    assert_not_predicate model, :content_changed?
  end

  def test_values_cast_from_nil_are_persisted_as_nil
    # This is required to fulfil the following contract, which must be universally
    # true in Active Record:
    #
    # model.attribute = value
    # assert_equal model.attribute, model.tap(&:save).reload.attribute
    Topic.serialize(:content, type: Hash)
    topic = Topic.create!(content: {})
    topic2 = Topic.create!(content: nil)

    assert_equal [topic, topic2], Topic.where(content: nil).sort_by(&:id)
  end

  def test_serialized_attribute_can_be_defined_in_abstract_classes
    klass = Class.new(ActiveRecord::Base) do
      self.abstract_class = true
      self.table_name = nil
      serialize(:content, type: Hash)
    end

    subclass = Class.new(klass) do
      self.table_name = "topics"
    end

    subclass.define_attribute_methods

    topic = subclass.create!(content: { foo: 1 })
    assert_equal [topic], subclass.where(content: { foo: 1 }).to_a
  end

  def test_nil_is_always_persisted_as_null
    Topic.serialize(:content, type: Hash)

    topic = Topic.create!(content: { foo: "bar" })
    topic.update_attribute :content, nil
    assert_equal [topic], Topic.where(content: nil)
  end

  class EncryptedType < ActiveRecord::Type::Text
    include ActiveModel::Type::Helpers::Mutable

    attr_reader :subtype, :encryptor

    def initialize(subtype: ActiveModel::Type::String.new)
      super()

      @subtype   = subtype
      @encryptor = ActiveSupport::MessageEncryptor.new("abcd" * 8)
    end

    def serialize(value)
      subtype.serialize(value).yield_self do |cleartext|
        encryptor.encrypt_and_sign(cleartext) unless cleartext.nil?
      end
    end

    def deserialize(ciphertext)
      encryptor.decrypt_and_verify(ciphertext)
        .yield_self { |cleartext| subtype.deserialize(cleartext) } unless ciphertext.nil?
    end

    def changed_in_place?(old, new)
      if old.nil?
        !new.nil?
      else
        deserialize(old) != new
      end
    end
  end

  def test_decorated_type_with_type_for_attribute
    old_registry = ActiveRecord::Type.registry
    ActiveRecord::Type.registry = ActiveRecord::Type.registry.dup
    ActiveRecord::Type.register :encrypted, EncryptedType

    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      store :content, coder: ActiveRecord::Coders::JSON
      attribute :content, :encrypted, subtype: type_for_attribute(:content)
    end

    topic = klass.create!(content: { trial: true })

    assert_equal({ "trial" => true }, topic.content)
  ensure
    ActiveRecord::Type.registry = old_registry
  end

  def test_decorated_type_with_decorator_block
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      store :content, coder: ActiveRecord::Coders::JSON
      decorate_attributes([:content]) do |name, type|
        EncryptedType.new(subtype: type)
      end
    end

    topic = klass.create!(content: { trial: true })
    assert_equal({ "trial" => true }, topic.content)
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
      serialize :foo, coder: coder
    end

    topic = model.create!(foo: "bar")
    topic.foo
    assert_not_predicate topic, :changed?
  end

  def test_serialized_attribute_works_under_concurrent_initial_access
    model = Class.new(Topic)

    topic = model.create!
    topic.update group: "1"

    model.serialize :group, coder: JSON
    model.reset_column_information

    # This isn't strictly necessary for the test, but a little bit of
    # knowledge of internals allows us to make failures far more likely.
    model.define_singleton_method(:define_attribute) do |*args, **options|
      Thread.pass
      super(*args, **options)
    end

    threads = 4.times.map do
      Thread.new do
        topic.reload.group
      end
    end

    # All the threads should retrieve the value knowing it is JSON, and
    # thus decode it. If this fails, some threads will instead see the
    # raw string ("1"), or raise an exception.
    assert_equal [1] * threads.size, threads.map(&:value)
  end
end

class SerializedAttributeTestWithYamlSafeLoad < SerializedAttributeTest
  def setup
    @use_yaml_unsafe_load = ActiveRecord.use_yaml_unsafe_load
    @yaml_column_permitted_classes_default = ActiveRecord.yaml_column_permitted_classes
    ActiveRecord.use_yaml_unsafe_load = false
  end

  def teardown
    Topic.serialize("content")
    ActiveRecord.yaml_column_permitted_classes = @yaml_column_permitted_classes_default
    ActiveRecord.use_yaml_unsafe_load = @use_yaml_unsafe_load
  end

  def test_serialized_attribute
    Topic.serialize("content", type: String)

    myobj = String.new("value1")
    topic = Topic.create("content" => myobj)
    assert_equal(myobj, topic.content)

    topic.reload
    assert_equal(myobj, topic.content)
  end

  def test_serialized_attribute_on_custom_attribute_with_default
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      attribute :content, default: { "key" => "value" }
      serialize :content, type: Hash
    end

    t = klass.new
    assert_equal({ "key" => "value" }, t.content)
  end

  def test_nil_is_always_persisted_as_null
    Topic.serialize(:content, type: Hash)

    topic = Topic.create!(content: { "foo" => "bar" })
    topic.update_attribute :content, nil
    assert_equal [topic], Topic.where(content: nil)
  end

  def test_serialized_attribute_with_default
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      serialize(:content, type: Hash, default: { "key" => "value" })
    end

    t = klass.new
    assert_equal({ "key" => "value" }, t.content)
  end

  def test_serialized_attributes_from_database_on_subclass
    Topic.serialize :content, type: Hash

    t = ImportantTopic.new(content: { "foo" => "bar" })
    assert_equal({ "foo" => "bar" }, t.content)
    t.save!
    t = ImportantTopic.last
    assert_equal({ "foo" => "bar" }, t.content)
  end

  def test_serialized_attribute_on_alias_attribute
    klass = Class.new(ActiveRecord::Base) do
      self.table_name = Topic.table_name
      alias_attribute :object, :content
      serialize :object, type: Hash
    end

    myobj = { "somevalue" => "thevalue" }
    topic = klass.create!(object: myobj)
    assert_equal(myobj, topic.object)

    topic.reload
    assert_equal(myobj, topic.object)
  end

  def test_unexpected_serialized_type
    Topic.serialize :content, type: Hash
    topic = Topic.create!(content: { "zomg" => true })

    Topic.serialize :content, type: Array

    topic.reload
    error = assert_raise(ActiveRecord::SerializationTypeMismatch) do
      topic.content
    end
    expected = "can't load `content`: was supposed to be a Array, but was a Hash. -- #{{ "zomg" => true }}"
    assert_equal expected, error.to_s
  end

  def test_serialize_attribute_via_select_method_when_time_zone_available
    with_timezone_config aware_attributes: true do
      Topic.serialize(:content, type: Hash)

      myobj = { "somevalue" => "thevalue" }
      topic = Topic.create(content: myobj)

      assert_equal(myobj, Topic.select(:content).find(topic.id).content)
      assert_raise(ActiveModel::MissingAttributeError) { Topic.select(:id).find(topic.id).content }
    end
  end

  def test_should_raise_exception_on_serialized_attribute_with_type_mismatch
    myobj = { "somevalue" => "thevalue" }
    topic = Topic.new(content: myobj)
    assert topic.save
    Topic.serialize(:content, type: String)
    assert_raise(ActiveRecord::SerializationTypeMismatch) { Topic.find(topic.id).content }
  end

  def test_serialized_time_attribute
    skip "Time is a DisallowedClass in Psych safe_load()."
  end

  def test_supports_permitted_classes_for_default_column_serializer
    Topic.serialize(:content, yaml: { permitted_classes: [Time] })
    topic = Topic.new(content: Time.now)
    assert topic.save
  end

  def test_changed_in_place_compare_serialized_representation
    Topic.serialize :content, type: Hash
    topic = Topic.create!(content: { "a" => 1, "b" => 2 })

    topic.content = { "a" => 1, "b" => 2 }
    assert_not_predicate topic, :content_changed?

    topic.content = { "b" => 2, "a" => 1 }
    assert_predicate topic, :content_changed?
  end

  def test_changed_in_place_compare_deserialized_representation_when_comparable_is_set
    Topic.serialize :content, type: Hash, comparable: true
    topic = Topic.create!(content: { "a" => 1, "b" => 2 })

    topic.content = { "a" => 1, "b" => 2 }
    assert_not_predicate topic, :content_changed?

    topic.content = { "b" => 2, "a" => 1 }
    assert_not_predicate topic, :content_changed?

    topic.content = {}
    assert_predicate topic, :content_changed?
  end
end
