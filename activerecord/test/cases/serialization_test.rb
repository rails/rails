require "cases/helper"
require 'models/contact'
require 'models/topic'
require 'models/reply'
require 'models/company'

class SerializationTest < ActiveRecord::TestCase

  fixtures :topics, :companies, :accounts

  FORMATS = [ :xml, :json ]

  def setup
    @contact_attributes = {
      :name        => 'aaron stack',
      :age         => 25,
      :avatar      => 'binarydata',
      :created_at  => Time.utc(2006, 8, 1),
      :awesome     => false,
      :preferences => { :gem => '<strong>ruby</strong>' }
    }

    @contact = Contact.new(@contact_attributes)
  end

  def test_serialized_init_with
    topic = Topic.allocate
    topic.init_with('attributes' => { 'content' => '--- foo' })
    assert_equal 'foo', topic.content
  end

  def test_to_xml
    xml = REXML::Document.new(topics(:first).to_xml(:indent => 0))
    bonus_time_in_current_timezone = topics(:first).bonus_time.xmlschema
    written_on_in_current_timezone = topics(:first).written_on.xmlschema
    last_read_in_current_timezone = topics(:first).last_read.xmlschema

    assert_equal "topic", xml.root.name
    assert_equal "The First Topic" , xml.elements["//title"].text
    assert_equal "David" , xml.elements["//author-name"].text
    assert_match "Have a nice day", xml.elements["//content"].text

    assert_equal "1", xml.elements["//id"].text
    assert_equal "integer" , xml.elements["//id"].attributes['type']

    assert_equal "1", xml.elements["//replies-count"].text
    assert_equal "integer" , xml.elements["//replies-count"].attributes['type']

    assert_equal written_on_in_current_timezone, xml.elements["//written-on"].text
    assert_equal "datetime" , xml.elements["//written-on"].attributes['type']

    assert_equal "david@loudthinking.com", xml.elements["//author-email-address"].text

    assert_equal nil, xml.elements["//parent-id"].text
    assert_equal "integer", xml.elements["//parent-id"].attributes['type']
    assert_equal "true", xml.elements["//parent-id"].attributes['nil']

    if current_adapter?(:SybaseAdapter)
      assert_equal last_read_in_current_timezone, xml.elements["//last-read"].text
      assert_equal "datetime" , xml.elements["//last-read"].attributes['type']
    else
      # Oracle enhanced adapter allows to define Date attributes in model class (see topic.rb)
      assert_equal "2004-04-15", xml.elements["//last-read"].text
      assert_equal "date" , xml.elements["//last-read"].attributes['type']
    end

    # Oracle and DB2 don't have true boolean or time-only fields
    unless current_adapter?(:OracleAdapter, :DB2Adapter)
      assert_equal "false", xml.elements["//approved"].text
      assert_equal "boolean" , xml.elements["//approved"].attributes['type']

      assert_equal bonus_time_in_current_timezone, xml.elements["//bonus-time"].text
      assert_equal "datetime" , xml.elements["//bonus-time"].attributes['type']
    end
  end

  def test_to_xml_skipping_attributes
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :except => [:title, :replies_count])
    assert_equal "<topic>", xml.first(7)
    assert !xml.include?(%(<title>The First Topic</title>))
    assert xml.include?(%(<author-name>David</author-name>))

    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :except => [:title, :author_name, :replies_count])
    assert !xml.include?(%(<title>The First Topic</title>))
    assert !xml.include?(%(<author-name>David</author-name>))
  end

  def test_to_xml_including_has_many_association
    xml = topics(:first).to_xml(:indent => 0, :skip_instruct => true, :include => :replies, :except => :replies_count)
    assert_equal "<topic>", xml.first(7)
    assert xml.include?(%(<replies type="array"><reply>))
    assert xml.include?(%(<title>The Second Topic of the day</title>))
  end

  def test_array_to_xml_including_has_many_association
    xml = [ topics(:first), topics(:second) ].to_xml(:indent => 0, :skip_instruct => true, :include => :replies)
    assert xml.include?(%(<replies type="array"><reply>))
  end

  def test_array_to_xml_including_methods
    xml = [ topics(:first), topics(:second) ].to_xml(:indent => 0, :skip_instruct => true, :methods => [ :topic_id ])
    assert xml.include?(%(<topic-id type="integer">#{topics(:first).topic_id}</topic-id>)), xml
    assert xml.include?(%(<topic-id type="integer">#{topics(:second).topic_id}</topic-id>)), xml
  end

  def test_array_to_xml_including_has_one_association
    xml = [ companies(:first_firm), companies(:rails_core) ].to_xml(:indent => 0, :skip_instruct => true, :include => :account)
    assert xml.include?(companies(:first_firm).account.to_xml(:indent => 0, :skip_instruct => true))
    assert xml.include?(companies(:rails_core).account.to_xml(:indent => 0, :skip_instruct => true))
  end

  def test_array_to_xml_including_belongs_to_association
    xml = [ companies(:first_client), companies(:second_client), companies(:another_client) ].to_xml(:indent => 0, :skip_instruct => true, :include => :firm)
    assert xml.include?(companies(:first_client).to_xml(:indent => 0, :skip_instruct => true))
    assert xml.include?(companies(:second_client).firm.to_xml(:indent => 0, :skip_instruct => true))
    assert xml.include?(companies(:another_client).firm.to_xml(:indent => 0, :skip_instruct => true))
  end

  def test_to_xml_including_belongs_to_association
    xml = companies(:first_client).to_xml(:indent => 0, :skip_instruct => true, :include => :firm)
    assert !xml.include?("<firm>")

    xml = companies(:second_client).to_xml(:indent => 0, :skip_instruct => true, :include => :firm)
    assert xml.include?("<firm>")
  end

  def test_to_xml_including_multiple_associations
    xml = companies(:first_firm).to_xml(:indent => 0, :skip_instruct => true, :include => [ :clients, :account ])
    assert_equal "<firm>", xml.first(6)
    assert xml.include?(%(<account>))
    assert xml.include?(%(<clients type="array"><client>))
  end

  def test_to_xml_including_multiple_associations_with_options
    xml = companies(:first_firm).to_xml(
      :indent  => 0, :skip_instruct => true,
      :include => { :clients => { :only => :name } }
    )

    assert_equal "<firm>", xml.first(6)
    assert xml.include?(%(<client><name>Summit</name></client>))
    assert xml.include?(%(<clients type="array"><client>))
  end

  def test_to_xml_including_methods
    xml = Company.new.to_xml(:methods => :arbitrary_method, :skip_instruct => true)
    assert_equal "<company>", xml.first(9)
    assert xml.include?(%(<arbitrary-method>I am Jack's profound disappointment</arbitrary-method>))
  end

  def test_to_xml_with_block
    value = "Rockin' the block"
    xml = Company.new.to_xml(:skip_instruct => true) do |_xml|
      _xml.tag! "arbitrary-element", value
    end
    assert_equal "<company>", xml.first(9)
    assert xml.include?(%(<arbitrary-element>#{value}</arbitrary-element>))
  end

  def test_serialize_should_be_reversible
    for format in FORMATS
      @serialized = Contact.new.send("to_#{format}")
      contact = Contact.new.send("from_#{format}", @serialized)

      assert_equal @contact_attributes.keys.collect(&:to_s).sort, contact.attributes.keys.collect(&:to_s).sort, "For #{format}"
    end
  end

  def test_serialize_should_allow_attribute_only_filtering
    for format in FORMATS
      @serialized = Contact.new(@contact_attributes).send("to_#{format}", :only => [ :age, :name ])
      contact = Contact.new.send("from_#{format}", @serialized)
      assert_equal @contact_attributes[:name], contact.name, "For #{format}"
      assert_nil contact.avatar, "For #{format}"
    end
  end

  def test_serialize_should_allow_attribute_except_filtering
    for format in FORMATS
      @serialized = Contact.new(@contact_attributes).send("to_#{format}", :except => [ :age, :name ])
      contact = Contact.new.send("from_#{format}", @serialized)
      assert_nil contact.name, "For #{format}"
      assert_nil contact.age, "For #{format}"
      assert_equal @contact_attributes[:awesome], contact.awesome, "For #{format}"
    end
  end

  def test_serialize_should_xml_skip_instruct_for_included_records
    @contact.alternative = Contact.new(:name => 'Copa Cabana')
    @serialized = @contact.to_xml(:include => [ :alternative ])
    assert_equal @serialized.index('<?xml '), 0
    assert_nil @serialized.index('<?xml ', 1)
  end
end
