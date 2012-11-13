require "cases/helper"
require 'models/contact'
require 'models/topic'

class SerializationTest < ActiveRecord::TestCase
  FORMATS = [ :xml, :json ]

  def setup
    @contact_attributes = {
      :name           => 'aaron stack',
      :age            => 25,
      :avatar         => 'binarydata',
      :created_at     => Time.utc(2006, 8, 1),
      :awesome        => false,
      :preferences    => { :gem => '<strong>ruby</strong>' },
      :alternative_id => nil,
      :id             => nil
    }
  end

  def test_serialize_should_be_reversible
    FORMATS.each do |format|
      @serialized = Contact.new.send("to_#{format}")
      contact = Contact.new.send("from_#{format}", @serialized)

      assert_equal @contact_attributes.keys.collect(&:to_s).sort, contact.attributes.keys.collect(&:to_s).sort, "For #{format}"
    end
  end

  def test_serialize_should_allow_attribute_only_filtering
    FORMATS.each do |format|
      @serialized = Contact.new(@contact_attributes).send("to_#{format}", :only => [ :age, :name ])
      contact = Contact.new.send("from_#{format}", @serialized)
      assert_equal @contact_attributes[:name], contact.name, "For #{format}"
      assert_nil contact.avatar, "For #{format}"
    end
  end

  def test_serialize_should_allow_attribute_except_filtering
    FORMATS.each do |format|
      @serialized = Contact.new(@contact_attributes).send("to_#{format}", :except => [ :age, :name ])
      contact = Contact.new.send("from_#{format}", @serialized)
      assert_nil contact.name, "For #{format}"
      assert_nil contact.age, "For #{format}"
      assert_equal @contact_attributes[:awesome], contact.awesome, "For #{format}"
    end
  end

  def test_include_root_in_json_allows_inheritance
    original_root_in_json = ActiveRecord::Base.include_root_in_json
    ActiveRecord::Base.include_root_in_json = true

    klazz = Class.new(ActiveRecord::Base)
    klazz.table_name = 'topics'
    assert klazz.include_root_in_json

    klazz.include_root_in_json = false
    assert ActiveRecord::Base.include_root_in_json
    assert !klazz.include_root_in_json
    assert !klazz.new.include_root_in_json
  ensure
    ActiveRecord::Base.include_root_in_json = original_root_in_json
  end
end
