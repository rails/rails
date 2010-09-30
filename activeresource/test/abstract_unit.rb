require File.expand_path('../../../load_paths', __FILE__)

lib = File.expand_path("#{File.dirname(__FILE__)}/../lib")
$:.unshift(lib) unless $:.include?('lib') || $:.include?(lib)

require 'rubygems'
require 'test/unit'
require 'active_resource'
require 'active_support'
require 'active_support/test_case'

require 'setter_trap'

require 'logger'
ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

begin
  require 'ruby-debug'
rescue LoadError
end

def setup_response
  @default_request_headers = { 'Content-Type' => 'application/xml' }
  @matz  = { :id => 1, :name => 'Matz' }.to_xml(:root => 'person')
  @david = { :id => 2, :name => 'David' }.to_xml(:root => 'person')
  @greg  = { :id => 3, :name => 'Greg' }.to_xml(:root => 'person')
  @addy  = { :id => 1, :street => '12345 Street', :country => 'Australia' }.to_xml(:root => 'address')
  @rick = { :name => "Rick", :age => 25 }.to_xml(:root => "person")
  @joe    = { 'person' => { :id => 6, :name => 'Joe' }}.to_json
  @people = [{ :id => 1, :name => 'Matz' }, { :id => 2, :name => 'David' }].to_xml(:root => 'people')
  @people_david = [{ :id => 2, :name => 'David' }].to_xml(:root => 'people')
  @addresses = [{ :id => 1, :street => '12345 Street', :country => 'Australia' }].to_xml(:root => 'addresses')

  # - deep nested resource -
  # - Luis (Customer)
  #   - JK (Customer::Friend)
  #     - Mateo (Customer::Friend::Brother)
  #       - Edith (Customer::Friend::Brother::Child)
  #       - Martha (Customer::Friend::Brother::Child)
  #     - Felipe (Customer::Friend::Brother)
  #       - Bryan (Customer::Friend::Brother::Child)
  #       - Luke (Customer::Friend::Brother::Child)
  #   - Eduardo (Customer::Friend)
  #     - Sebas (Customer::Friend::Brother)
  #       - Andres (Customer::Friend::Brother::Child)
  #       - Jorge (Customer::Friend::Brother::Child)
  #     - Elsa (Customer::Friend::Brother)
  #       - Natacha (Customer::Friend::Brother::Child)
  #     - Milena (Customer::Friend::Brother)
  #
  @luis = {:id => 1, :name => 'Luis',
            :friends => [{:name => 'JK',
                          :brothers => [{:name => 'Mateo',
                                         :children => [{:name => 'Edith'},{:name => 'Martha'}]},
                                        {:name => 'Felipe',
                                         :children => [{:name => 'Bryan'},{:name => 'Luke'}]}]},
                         {:name => 'Eduardo',
                          :brothers => [{:name => 'Sebas',
                                         :children => [{:name => 'Andres'},{:name => 'Jorge'}]},
                                        {:name => 'Elsa',
                                         :children => [{:name => 'Natacha'}]},
                                        {:name => 'Milena',
                                         :children => []}]}]}.to_xml(:root => 'customer')
  # - resource with yaml array of strings; for ARs using serialize :bar, Array
  @marty = <<-eof.strip
    <?xml version=\"1.0\" encoding=\"UTF-8\"?>
    <person>
      <id type=\"integer\">5</id>
      <name>Marty</name>
      <colors type=\"yaml\">---
    - \"red\"
    - \"green\"
    - \"blue\"
    </colors>
    </person>
  eof

  @startup_sound = { 
      :name => "Mac Startup Sound", :author => { :name => "Jim Reekes" } 
    }.to_xml(:root => 'sound') 

  ActiveResource::HttpMock.respond_to do |mock|
    mock.get    "/people/1.xml",                {}, @matz
    mock.get    "/people/2.xml",                {}, @david
    mock.get    "/people/5.xml",                {}, @marty
    mock.get    "/people/Greg.xml",             {}, @greg
    mock.get    "/people/6.json",               {}, @joe
    mock.get    "/people/4.xml",                {'key' => 'value'}, nil, 404
    mock.put    "/people/1.xml",                {}, nil, 204
    mock.delete "/people/1.xml",                {}, nil, 200
    mock.delete "/people/2.xml",                {}, nil, 400
    mock.get    "/people/99.xml",               {}, nil, 404
    mock.post   "/people.xml",                  {}, @rick, 201, 'Location' => '/people/5.xml'
    mock.get    "/people.xml",                  {}, @people
    mock.get    "/people/1/addresses.xml",      {}, @addresses
    mock.get    "/people/1/addresses/1.xml",    {}, @addy
    mock.get    "/people/1/addresses/2.xml",    {}, nil, 404
    mock.get    "/people/2/addresses.xml",      {}, nil, 404
    mock.get    "/people/2/addresses/1.xml",    {}, nil, 404
    mock.get    "/people/Greg/addresses/1.xml", {}, @addy
    mock.put    "/people/1/addresses/1.xml",    {}, nil, 204
    mock.delete "/people/1/addresses/1.xml",    {}, nil, 200
    mock.post   "/people/1/addresses.xml",      {}, nil, 201, 'Location' => '/people/1/addresses/5'
    mock.get    "/people/1/addresses/99.xml",   {}, nil, 404
    mock.get    "/people//addresses.xml",       {}, nil, 404
    mock.get    "/people//addresses/1.xml",     {}, nil, 404
    mock.put    "/people//addresses/1.xml",     {}, nil, 404
    mock.delete "/people//addresses/1.xml",     {}, nil, 404
    mock.post   "/people//addresses.xml",       {}, nil, 404
    mock.head   "/people/1.xml",                {}, nil, 200
    mock.head   "/people/Greg.xml",             {}, nil, 200
    mock.head   "/people/99.xml",               {}, nil, 404
    mock.head   "/people/1/addresses/1.xml",    {}, nil, 200
    mock.head   "/people/1/addresses/2.xml",    {}, nil, 404
    mock.head   "/people/2/addresses/1.xml",    {}, nil, 404
    mock.head   "/people/Greg/addresses/1.xml", {}, nil, 200
    # customer
    mock.get    "/customers/1.xml",             {}, @luis
    # sound
    mock.get    "/sounds/1.xml",                {}, @startup_sound
  end

  Person.user = nil
  Person.password = nil
end
