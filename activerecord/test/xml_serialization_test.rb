require 'abstract_unit'
require 'fixtures/contact'
require 'fixtures/post'
require 'fixtures/author'
require 'fixtures/tagging'
require 'fixtures/comment'

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

  def test_should_include_yielded_additions
    @xml = Contact.new.to_xml do |xml|
      xml.creator "David"
    end

    assert_match %r{<creator>David</creator>}, @xml
  end
end

class DefaultXmlSerializationTest < Test::Unit::TestCase
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
  
  def test_should_serialize_yaml
    assert_match %r{<preferences type=\"yaml\"></preferences>}, @xml
  end
end

class DatabaseConnectedXmlSerializationTest < Test::Unit::TestCase
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