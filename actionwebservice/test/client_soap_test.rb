require File.dirname(__FILE__) + '/abstract_client'


module ClientSoapTest
  PORT = 8998

  class SoapClientLet < ClientTest::AbstractClientLet
    def do_POST(req, res)
      test_request = ActionController::TestRequest.new
      test_request.request_parameters['action'] = req.path.gsub(/^\//, '').split(/\//)[1]
      test_request.env['REQUEST_METHOD'] = "POST"
      test_request.env['HTTP_CONTENTTYPE'] = 'text/xml'
      test_request.env['HTTP_SOAPACTION'] = req.header['soapaction'][0]
      test_request.env['RAW_POST_DATA'] = req.body
      response = ActionController::TestResponse.new
      @controller.process(test_request, response)
      res.header['content-type'] = 'text/xml'
      res.body = response.body
    rescue Exception => e
      $stderr.puts e.message
      $stderr.puts e.backtrace.join("\n")
    end
  end

  class ClientContainer < ActionController::Base
    web_client_api :client, :soap, "http://localhost:#{PORT}/client/api", :api => ClientTest::API
    web_client_api :invalid, :null, "", :api => true

    def get_client
      client
    end

    def get_invalid
      invalid
    end
  end

  class SoapServer < ClientTest::AbstractServer
    def create_clientlet(controller)
      SoapClientLet.new(controller)
    end

    def server_port
      PORT
    end
  end
end

class TC_ClientSoap < Test::Unit::TestCase
  include ClientTest
  include ClientSoapTest
  
  fixtures :users

  def setup
    @server = SoapServer.instance
    @container = @server.container
    @client = ActionWebService::Client::Soap.new(API, "http://localhost:#{@server.server_port}/client/api")
  end

  def test_void
    assert(@container.value_void.nil?)
    @client.void
    assert(!@container.value_void.nil?)
  end

  def test_normal
    assert(@container.value_normal.nil?)
    assert_equal(5, @client.normal(5, 6))
    assert_equal([5, 6], @container.value_normal)
    assert_equal(5, @client.normal("7", "8"))
    assert_equal([7, 8], @container.value_normal)
    assert_equal(5, @client.normal(true, false))
  end

  def test_array_return
    assert(@container.value_array_return.nil?)
    new_person = Person.new
    new_person.firstnames = ["one", "two"]
    new_person.lastname = "last"
    assert_equal([new_person], @client.array_return)
    assert_equal([new_person], @container.value_array_return)
  end

  def test_struct_pass
    assert(@container.value_struct_pass.nil?)
    new_person = Person.new
    new_person.firstnames = ["one", "two"]
    new_person.lastname = "last"
    assert_equal(true, @client.struct_pass([new_person]))
    assert_equal([[new_person]], @container.value_struct_pass)
  end
  
  def test_nil_struct_return
    assert_nil @client.nil_struct_return
  end
  
  def test_inner_nil
    outer = @client.inner_nil
    assert_equal 'outer', outer.name
    assert_nil outer.inner
  end

  def test_client_container
    assert_equal(50, ClientContainer.new.get_client.client_container)
    assert(ClientContainer.new.get_invalid.nil?)
  end

  def test_named_parameters
    assert(@container.value_named_parameters.nil?)
    assert(@client.named_parameters("key", 5).nil?)
    assert_equal(["key", 5], @container.value_named_parameters)
  end

  def test_capitalized_method_name
    @container.value_normal = nil
    assert_equal(5, @client.Normal(5, 6))
    assert_equal([5, 6], @container.value_normal)
    @container.value_normal = nil
  end
  
  def test_model_return
    user = @client.user_return
    assert_equal 1, user.id
    assert_equal 'Kent', user.name
    assert user.active?
    assert_kind_of Date, user.created_on
    assert_equal Date.today, user.created_on
  end
  
  def test_with_model
    with_model = @client.with_model_return
    assert_equal 'Kent', with_model.user.name
    assert_equal 2, with_model.users.size
    with_model.users.each do |user|
      assert_kind_of User, user
    end
  end
  
  def test_scoped_model_return
    scoped_model = @client.scoped_model_return
    assert_kind_of Accounting::User, scoped_model
    assert_equal 'Kent', scoped_model.name
  end
  
  def test_multi_dim_return
    md_struct = @client.multi_dim_return
    assert_kind_of Array, md_struct.pref
    assert_equal 2, md_struct.pref.size
    assert_kind_of Array, md_struct.pref[0]
  end
end
