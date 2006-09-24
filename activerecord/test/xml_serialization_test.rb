require 'abstract_unit'
require 'fixtures/post'
require 'fixtures/author'

class Contact < ActiveRecord::Base
  # mock out self.columns so no pesky db is needed for these tests
  def self.columns() @columns ||= []; end
  def self.column(name, sql_type = nil, default = nil, null = true)
    columns << ActiveRecord::ConnectionAdapters::Column.new(name.to_s, default, sql_type.to_s, null)
  end

  column :name,       :string
  column :age,        :integer
  column :avatar,     :binary
  column :created_at, :datetime
  column :awesome,    :boolean
end

class XmlSerializationTest < Test::Unit::TestCase
  def test_should_serialize_default_root
    @xml = Contact.new.to_xml
    assert_match %r{^<contact>},  @xml
    assert_match %r{</contact>$}, @xml
  end
  
  def test_should_serialize_default_root_with_namespace
    @xml = Contact.new.to_xml :namespace=>"http://xml.rubyonrails.org/contact"
    assert_match %r{^<contact xmlns="http://xml.rubyonrails.org/contact">},  @xml
    assert_match %r{</contact>$}, @xml
  end
  
  def test_should_serialize_custom_root
    @xml = Contact.new.to_xml :root => 'xml_contact'
    assert_match %r{^<xml-contact>},  @xml
    assert_match %r{</xml-contact>$}, @xml
  end
  
  def test_should_allow_undasherized_tags
    @xml = Contact.new.to_xml :root => 'xml_contact', :dasherize => false
    assert_match %r{^<xml_contact>},  @xml
    assert_match %r{</xml_contact>$}, @xml
    assert_match %r{<created_at},     @xml
  end

  def test_should_allow_attribute_filtering
    @xml = Contact.new.to_xml :only => [:age, :name]
    assert_match %r{<name},          @xml
    assert_match %r{<age},           @xml
    assert_no_match %r{<created-at}, @xml
    
    @xml = Contact.new.to_xml :except => [:age, :name]
    assert_no_match %r{<name},    @xml
    assert_no_match %r{<age},     @xml
    assert_match %r{<created-at}, @xml
  end
end

class DefaultXmlSerializationTest < Test::Unit::TestCase
  def setup
    @xml = Contact.new(:name => 'aaron stack', :age => 25, :avatar => 'binarydata', :created_at => Time.utc(2006, 8, 1), :awesome => false).to_xml
  end

  def test_should_serialize_string
    assert_match %r{<name>aaron stack</name>},     @xml
  end
  
  def test_should_serialize_integer
    assert_match %r{<age type="integer">25</age>}, @xml
  end
  
  def test_should_serialize_binary
    assert_match %r{YmluYXJ5ZGF0YQ==\n</avatar>},    @xml
    assert_match %r{<avatar(.*)(type="binary")},     @xml
    assert_match %r{<avatar(.*)(encoding="base64")}, @xml
  end
  
  def test_should_serialize_datetime
    assert_match %r{<created-at type=\"datetime\">2006-08-01T00:00:00Z</created-at>}, @xml
  end
  
  def test_should_serialize_boolean
    assert_match %r{<awesome type=\"boolean\">false</awesome>}, @xml
  end
end

class NilXmlSerializationTest < Test::Unit::TestCase
  def setup
    @xml = Contact.new.to_xml(:root => 'xml_contact')
  end

  def test_should_serialize_string
    assert_match %r{<name></name>},     @xml
  end
  
  def test_should_serialize_integer
    assert_match %r{<age type="integer"></age>}, @xml
  end
  
  def test_should_serialize_binary
    assert_match %r{></avatar>},                     @xml
    assert_match %r{<avatar(.*)(type="binary")},     @xml
    assert_match %r{<avatar(.*)(encoding="base64")}, @xml
  end
  
  def test_should_serialize_datetime
    assert_match %r{<created-at type=\"datetime\"></created-at>}, @xml
  end
  
  def test_should_serialize_boolean
    assert_match %r{<awesome type=\"boolean\"></awesome>}, @xml
  end
end

class DatabaseConnectedXmlSerializationTest < Test::Unit::TestCase
  fixtures :authors, :posts
  # to_xml used to mess with the hash the user provided which
  # caused the builder to be reused
  def test_passing_hash_shouldnt_reuse_builder
    options = {:include=>:posts}
    david = authors(:david)
    first_xml_size = david.to_xml(options).size
    second_xml_size = david.to_xml(options).size
    assert_equal first_xml_size, second_xml_size
  end
end