require "#{File.dirname(__FILE__)}/abstract_unit"
require "fixtures/person"

class BaseTest < Test::Unit::TestCase
  def setup
    ActiveResource::HttpMock.respond_to(
      ActiveResource::Request.new(:get,    "/people/1.xml") => ActiveResource::Response.new("<person><name>Matz</name><id type='integer'>1</id></person>"),
      ActiveResource::Request.new(:get,    "/people/2.xml") => ActiveResource::Response.new("<person><name>David</name><id type='integer'>2</id></person>"),
      ActiveResource::Request.new(:put,    "/people/1.xml") => ActiveResource::Response.new({}, 200),
      ActiveResource::Request.new(:delete, "/people/1.xml") => ActiveResource::Response.new({}, 200),
      ActiveResource::Request.new(:delete, "/people/2.xml") => ActiveResource::Response.new({}, 400),
      ActiveResource::Request.new(:post,   "/people.xml")     => ActiveResource::Response.new({}, 200),
      ActiveResource::Request.new(:get,    "/people/99.xml")  => ActiveResource::Response.new({}, 404),
      ActiveResource::Request.new(:get,    "/people.xml")     => ActiveResource::Response.new(
        "<people><person><name>Matz</name><id type='integer'>1</id></person><person><name>David</name><id type='integer'>2</id></person></people>"
      )
    )
  end


  def test_site_accessor_accepts_uri_or_string_argument
    site = URI.parse('http://localhost')

    assert_nothing_raised { Person.site = 'http://localhost' }
    assert_equal site, Person.site

    assert_nothing_raised { Person.site = site }
    assert_equal site, Person.site
  end


  def test_collection_name
    assert_equal "people", Person.collection_name
  end

  def test_find_by_id
    matz = Person.find(1)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_find_all
    all = Person.find(:all)
    assert_equal 2, all.size
    assert_kind_of Person, all.first
    assert_equal "Matz", all.first.name
    assert_equal "David", all.last.name
  end

  def test_find_first
    matz = Person.find(:first)
    assert_kind_of Person, matz
    assert_equal "Matz", matz.name
  end

  def test_find_by_id_not_found
    assert_raises(ActiveResource::ResourceNotFound) { Person.find(99) }
  end
  
  def test_update
    matz = Person.find(:first)
    matz.name = "David"
    assert_kind_of Person, matz
    assert_equal "David", matz.name
    matz.save
  end
  
  def test_destroy
    assert Person.find(1).destroy
    assert_raises(ActiveResource::ClientError) { Person.find(2).destroy }
  end
end
