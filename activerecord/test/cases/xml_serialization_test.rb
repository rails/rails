require "cases/helper"
require 'models/contact'
require 'models/post'
require 'models/author'
require 'models/tagging'
require 'models/comment'

class XmlSerializationTest < ActiveRecord::TestCase
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

  def test_should_allow_camelized_tags
    @xml = Contact.new.to_xml :root => 'xml_contact', :camelize => true
    assert_match %r{^<XmlContact>},  @xml
    assert_match %r{</XmlContact>$}, @xml
    assert_match %r{<CreatedAt},    @xml
  end

  def test_should_allow_skipped_types
    @xml = Contact.new(:age => 25).to_xml :skip_types => true
    assert %r{<age>25</age>}.match(@xml)
  end

  def test_should_include_yielded_additions
    @xml = Contact.new.to_xml do |xml|
      xml.creator "David"
    end
    assert_match %r{<creator>David</creator>}, @xml
  end
end

class DefaultXmlSerializationTest < ActiveRecord::TestCase
  def setup
    @xml = Contact.new(:name => 'aaron stack', :age => 25, :avatar => 'binarydata', :created_at => Time.utc(2006, 8, 1), :awesome => false, :preferences => { :gem => 'ruby' }).to_xml
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

  def test_should_serialize_yaml
    assert_match %r{<preferences type=\"yaml\">--- \n:gem: ruby\n</preferences>}, @xml
  end
end

class NilXmlSerializationTest < ActiveRecord::TestCase
  def setup
    @xml = Contact.new.to_xml(:root => 'xml_contact')
  end

  def test_should_serialize_string
    assert_match %r{<name nil="true"></name>},     @xml
  end

  def test_should_serialize_integer
    assert %r{<age (.*)></age>}.match(@xml)
    attributes = $1
    assert_match %r{nil="true"}, attributes
    assert_match %r{type="integer"}, attributes
  end

  def test_should_serialize_binary
    assert %r{<avatar (.*)></avatar>}.match(@xml)
    attributes = $1
    assert_match %r{type="binary"}, attributes
    assert_match %r{encoding="base64"}, attributes
    assert_match %r{nil="true"}, attributes
  end

  def test_should_serialize_datetime
    assert %r{<created-at (.*)></created-at>}.match(@xml)
    attributes = $1
    assert_match %r{nil="true"}, attributes
    assert_match %r{type="datetime"}, attributes
  end

  def test_should_serialize_boolean
    assert %r{<awesome (.*)></awesome>}.match(@xml)
    attributes = $1
    assert_match %r{type="boolean"}, attributes
    assert_match %r{nil="true"}, attributes
  end

  def test_should_serialize_yaml
    assert %r{<preferences(.*)></preferences>}.match(@xml)
    attributes = $1
    assert_match %r{type="yaml"}, attributes
    assert_match %r{nil="true"}, attributes
  end
end

class DatabaseConnectedXmlSerializationTest < ActiveRecord::TestCase
  fixtures :authors, :posts
  # to_xml used to mess with the hash the user provided which
  # caused the builder to be reused.  This meant the document kept
  # getting appended to.
  def test_passing_hash_shouldnt_reuse_builder
    options = {:include=>:posts}
    david = authors(:david)
    first_xml_size = david.to_xml(options).size
    second_xml_size = david.to_xml(options).size
    assert_equal first_xml_size, second_xml_size
  end

  def test_include_uses_association_name
    xml = authors(:david).to_xml :include=>:hello_posts, :indent => 0
    assert_match %r{<hello-posts type="array">}, xml
    assert_match %r{<hello-post type="Post">}, xml
    assert_match %r{<hello-post type="StiPost">}, xml
  end

  def test_included_associations_should_skip_types
    xml = authors(:david).to_xml :include=>:hello_posts, :indent => 0, :skip_types => true
    assert_match %r{<hello-posts>}, xml
    assert_match %r{<hello-post>}, xml
    assert_match %r{<hello-post>}, xml
  end

  def test_methods_are_called_on_object
    xml = authors(:david).to_xml :methods => :label, :indent => 0
    assert_match %r{<label>.*</label>}, xml
  end

  def test_should_not_call_methods_on_associations_that_dont_respond
    xml = authors(:david).to_xml :include=>:hello_posts, :methods => :label, :indent => 2
    assert !authors(:david).hello_posts.first.respond_to?(:label)
    assert_match %r{^  <label>.*</label>}, xml
    assert_no_match %r{^      <label>}, xml
  end

  def test_procs_are_called_on_object
    proc = Proc.new { |options| options[:builder].tag!('nationality', 'Danish') }
    xml = authors(:david).to_xml(:procs => [ proc ])
    assert_match %r{<nationality>Danish</nationality>}, xml
  end

  def test_dual_arity_procs_are_called_on_object
    proc = Proc.new { |options, record| options[:builder].tag!('name-reverse', record.name.reverse) }
    xml = authors(:david).to_xml(:procs => [ proc ])
    assert_match %r{<name-reverse>divaD</name-reverse>}, xml
  end

  def test_top_level_procs_arent_applied_to_associations
    author_proc = Proc.new { |options| options[:builder].tag!('nationality', 'Danish') }
    xml = authors(:david).to_xml(:procs => [ author_proc ], :include => :posts, :indent => 2)

    assert_match %r{^  <nationality>Danish</nationality>}, xml
    assert_no_match %r{^ {6}<nationality>Danish</nationality>}, xml
  end

  def test_procs_on_included_associations_are_called
    posts_proc = Proc.new { |options| options[:builder].tag!('copyright', 'DHH') }
    xml = authors(:david).to_xml(
      :indent => 2,
      :include => {
        :posts => { :procs => [ posts_proc ] }
      }
    )

    assert_no_match %r{^  <copyright>DHH</copyright>}, xml
    assert_match %r{^ {6}<copyright>DHH</copyright>}, xml
  end

  def test_should_include_empty_has_many_as_empty_array
    authors(:david).posts.delete_all
    xml = authors(:david).to_xml :include=>:posts, :indent => 2

    assert_equal [], Hash.from_xml(xml)['author']['posts']
    assert_match %r{^  <posts type="array"/>}, xml
  end

  def test_should_has_many_array_elements_should_include_type_when_different_from_guessed_value
    xml = authors(:david).to_xml :include=>:posts_with_comments, :indent => 2

    assert Hash.from_xml(xml)
    assert_match %r{^  <posts-with-comments type="array">}, xml
    assert_match %r{^    <posts-with-comment type="Post">}, xml
    assert_match %r{^    <posts-with-comment type="StiPost">}, xml

    types = Hash.from_xml(xml)['author']['posts_with_comments'].collect {|t| t['type'] }
    assert types.include?('SpecialPost')
    assert types.include?('Post')
    assert types.include?('StiPost')
  end

end
