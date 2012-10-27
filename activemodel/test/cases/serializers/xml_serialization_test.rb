require 'cases/helper'
require 'models/contact'
require 'active_support/core_ext/object/instance_variables'
require 'ostruct'

class Contact
  include ActiveModel::Serializers::Xml

  attr_accessor :address, :friends

  remove_method :attributes if method_defined?(:attributes)

  def attributes
    instance_values.except("address", "friends")
  end
end

module Admin
  class Contact < ::Contact
  end
end

class Customer < Struct.new(:name)
end

class Address
  include ActiveModel::Serializers::Xml

  attr_accessor :street, :city, :state, :zip

  def attributes
    instance_values
  end
end

class SerializableContact < Contact
  def serializable_hash(options={})
    super(options.merge(:only => [:name, :age]))
  end
end

class XmlSerializationTest < ActiveModel::TestCase
  def setup
    @contact = Contact.new
    @contact.name = 'aaron stack'
    @contact.age = 25
    @contact.created_at = Time.utc(2006, 8, 1)
    @contact.awesome = false
    customer = Customer.new
    customer.name = "John"
    @contact.preferences = customer
    @contact.address = Address.new
    @contact.address.street = "123 Lane"
    @contact.address.city = "Springfield"
    @contact.address.state = "CA"
    @contact.address.zip = 11111
    @contact.friends = [Contact.new, Contact.new]
  end

  test "should serialize default root" do
    @xml = @contact.to_xml
    assert_match %r{^<contact>},  @xml
    assert_match %r{</contact>$}, @xml
  end

  test "should serialize namespaced root" do
    @xml = Admin::Contact.new(@contact.attributes).to_xml
    assert_match %r{^<contact>},  @xml
    assert_match %r{</contact>$}, @xml
  end

  test "should serialize default root with namespace" do
    @xml = @contact.to_xml :namespace => "http://xml.rubyonrails.org/contact"
    assert_match %r{^<contact xmlns="http://xml.rubyonrails.org/contact">}, @xml
    assert_match %r{</contact>$}, @xml
  end

  test "should serialize custom root" do
    @xml = @contact.to_xml :root => 'xml_contact'
    assert_match %r{^<xml-contact>},  @xml
    assert_match %r{</xml-contact>$}, @xml
  end

  test "should allow undasherized tags" do
    @xml = @contact.to_xml :root => 'xml_contact', :dasherize => false
    assert_match %r{^<xml_contact>},  @xml
    assert_match %r{</xml_contact>$}, @xml
    assert_match %r{<created_at},     @xml
  end

  test "should allow camelized tags" do
    @xml = @contact.to_xml :root => 'xml_contact', :camelize => true
    assert_match %r{^<XmlContact>},  @xml
    assert_match %r{</XmlContact>$}, @xml
    assert_match %r{<CreatedAt},     @xml
  end

  test "should allow lower-camelized tags" do
    @xml = @contact.to_xml :root => 'xml_contact', :camelize => :lower
    assert_match %r{^<xmlContact>},  @xml
    assert_match %r{</xmlContact>$}, @xml
    assert_match %r{<createdAt},     @xml
  end

  test "should use serialiable hash" do
    @contact = SerializableContact.new
    @contact.name = 'aaron stack'
    @contact.age = 25

    @xml = @contact.to_xml
    assert_match %r{<name>aaron stack</name>}, @xml
    assert_match %r{<age type="integer">25</age>}, @xml
    assert_no_match %r{<awesome>}, @xml
  end

  test "should allow skipped types" do
    @xml = @contact.to_xml :skip_types => true
    assert_match %r{<age>25</age>}, @xml
  end

  test "should include yielded additions" do
    @xml = @contact.to_xml do |xml|
      xml.creator "David"
    end
    assert_match %r{<creator>David</creator>}, @xml
  end

  test "should serialize string" do
    assert_match %r{<name>aaron stack</name>}, @contact.to_xml
  end

  test "should serialize nil" do
    assert_match %r{<pseudonyms nil=\"true\"/>}, @contact.to_xml(:methods => :pseudonyms)
  end

  test "should serialize integer" do
    assert_match %r{<age type="integer">25</age>}, @contact.to_xml
  end

  test "should serialize datetime" do
    assert_match %r{<created-at type=\"datetime\">2006-08-01T00:00:00Z</created-at>}, @contact.to_xml
  end

  test "should serialize boolean" do
    assert_match %r{<awesome type=\"boolean\">false</awesome>}, @contact.to_xml
  end

  test "should serialize array" do
    assert_match %r{<social type=\"array\">\s*<social>twitter</social>\s*<social>github</social>\s*</social>}, @contact.to_xml(:methods => :social)
  end

  test "should serialize hash" do
    assert_match %r{<network>\s*<git type=\"symbol\">github</git>\s*</network>}, @contact.to_xml(:methods => :network)
  end

  test "should serialize yaml" do
    assert_match %r{<preferences type=\"yaml\">--- !ruby/struct:Customer(\s*)\nname: John\n</preferences>}, @contact.to_xml
  end

  test "should call proc on object" do
    proc = Proc.new { |options| options[:builder].tag!('nationality', 'unknown') }
    xml = @contact.to_xml(:procs => [ proc ])
    assert_match %r{<nationality>unknown</nationality>}, xml
  end

  test 'should supply serializable to second proc argument' do
    proc = Proc.new { |options, record| options[:builder].tag!('name-reverse', record.name.reverse) }
    xml = @contact.to_xml(:procs => [ proc ])
    assert_match %r{<name-reverse>kcats noraa</name-reverse>}, xml
  end

  test "should serialize string correctly when type passed" do
    xml = @contact.to_xml :type => 'Contact'
    assert_match %r{<contact type="Contact">}, xml
    assert_match %r{<name>aaron stack</name>}, xml
  end

  test "include option with singular association" do
    xml = @contact.to_xml :include => :address, :indent => 0
    assert xml.include?(@contact.address.to_xml(:indent => 0, :skip_instruct => true))
  end

  test "include option with plural association" do
    xml = @contact.to_xml :include => :friends, :indent => 0
    assert_match %r{<friends type="array">}, xml
    assert_match %r{<friend type="Contact">}, xml
  end

  test "multiple includes" do
    xml = @contact.to_xml :indent => 0, :skip_instruct => true, :include => [ :address, :friends ]
    assert xml.include?(@contact.address.to_xml(:indent => 0, :skip_instruct => true))
    assert_match %r{<friends type="array">}, xml
    assert_match %r{<friend type="Contact">}, xml
  end

  test "include with options" do
    xml = @contact.to_xml :indent  => 0, :skip_instruct => true, :include => { :address => { :only => :city } }
    assert xml.include?(%(><address><city>Springfield</city></address>))
  end

  test "propagates skip_types option to included associations" do
    xml = @contact.to_xml :include => :friends, :indent => 0, :skip_types => true
    assert_match %r{<friends>}, xml
    assert_match %r{<friend>}, xml
  end
end
