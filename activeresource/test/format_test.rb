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

  
  private
    def using_format(klass, mime_type_reference)
      previous_format = klass.format
      klass.format = mime_type_reference

      yield
    ensure
      klass.format = previous_format
    end
end