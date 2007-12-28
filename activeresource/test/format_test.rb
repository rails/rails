require "#{File.dirname(__FILE__)}/abstract_unit"
require "fixtures/person"

class FormatTest < Test::Unit::TestCase
  def setup
    @matz  = { :id => 1, :name => 'Matz' }
    @david = { :id => 2, :name => 'David' }
    
    @programmers = [ @matz, @david ]
  end
  
  def test_formats_on_single_element
    for format in [ :json, :xml ]
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.get "/people/1.#{format}", {}, ActiveResource::Formats[format].encode(@david)
        assert_equal @david[:name], Person.find(1).name
      end
    end
  end

  def test_formats_on_collection
    for format in [ :json, :xml ]
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.get "/people.#{format}", {}, ActiveResource::Formats[format].encode(@programmers)
        remote_programmers = Person.find(:all)
        assert_equal 2, remote_programmers.size
        assert remote_programmers.select { |p| p.name == 'David' }
      end
    end
  end

  def test_formats_on_custom_collection_method
    for format in [ :json, :xml ]
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.get "/people/retrieve.#{format}?name=David", {}, ActiveResource::Formats[format].encode([@david])
        remote_programmers = Person.get(:retrieve, :name => 'David')
        assert_equal 1, remote_programmers.size
        assert_equal @david[:id], remote_programmers[0]['id']
        assert_equal @david[:name], remote_programmers[0]['name']
      end
    end
  end
  
  def test_formats_on_custom_element_method
    for format in [ :json, :xml ]
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to do |mock|
          mock.get "/people/2.#{format}", {}, ActiveResource::Formats[format].encode(@david)
          mock.get "/people/2/shallow.#{format}", {}, ActiveResource::Formats[format].encode(@david)
        end
        remote_programmer = Person.find(2).get(:shallow)
        assert_equal @david[:id], remote_programmer['id']
        assert_equal @david[:name], remote_programmer['name']
      end
    end

    for format in [ :json, :xml ]
      ryan = ActiveResource::Formats[format].encode({ :name => 'Ryan' })
      using_format(Person, format) do
        ActiveResource::HttpMock.respond_to.post "/people/new/register.#{format}", {}, ryan, 201, 'Location' => "/people/5.#{format}"
        remote_ryan = Person.new(:name => 'Ryan')
        assert_equal ActiveResource::Response.new(ryan, 201, {'Location' => "/people/5.#{format}"}), remote_ryan.post(:register)
      end
    end
  end
  
  def test_setting_format_before_site
    resource = Class.new(ActiveResource::Base)
    resource.format = :json
    resource.site   = 'http://37s.sunrise.i:3000'
    assert_equal ActiveResource::Formats[:json], resource.connection.format
  end
  
  private
    def using_format(klass, mime_type_reference)
      previous_format = klass.format
      klass.format = mime_type_reference

      yield
    ensure
      klass.format = previous_format
    end
end