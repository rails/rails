require File.dirname(__FILE__) + '/../abstract_unit'

$:.unshift File.dirname(__FILE__) + '/../../../railties/lib'
require 'action_controller/integration'

uses_mocha 'integration' do

# Stub process for testing.
module ActionController
  module Integration
    class Session
      def process(*args)
      end

      def generic_url_rewriter
      end
    end
  end
end

class SessionTest < Test::Unit::TestCase
  def setup
    @session = ActionController::Integration::Session.new
  end
  def test_https_bang_works_and_sets_truth_by_default
    assert !@session.https?
    @session.https!
    assert @session.https?
    @session.https! false
    assert !@session.https?
  end

  def test_host!
    assert_not_equal "glu.ttono.us", @session.host
    @session.host! "rubyonrails.com"
    assert_equal "rubyonrails.com", @session.host
  end

  def test_follow_redirect_raises_when_no_redirect
    @session.stubs(:redirect?).returns(false)
    assert_raise(RuntimeError) { @session.follow_redirect! }
  end

  def test_follow_redirect_calls_get_and_returns_status
    @session.stubs(:redirect?).returns(true)
    @session.stubs(:headers).returns({"location" => ["www.google.com"]})
    @session.stubs(:status).returns(200)
    @session.expects(:get)
    assert_equal 200, @session.follow_redirect!
  end

  def test_get_via_redirect
    path = "/somepath"; args = {:id => '1'}

    @session.expects(:get).with(path,args)

    @session.stubs(:redirect?).returns(true, true, false)
    @session.expects(:follow_redirect!).times(2)

    @session.stubs(:status).returns(200)
    assert_equal 200, @session.get_via_redirect(path, args)
  end

  def test_post_via_redirect
    path = "/somepath"; args = {:id => '1'}

    @session.expects(:post).with(path,args)

    @session.stubs(:redirect?).returns(true, true, false)
    @session.expects(:follow_redirect!).times(2)

    @session.stubs(:status).returns(200)
    assert_equal 200, @session.post_via_redirect(path, args)
  end

  def test_url_for_with_controller
    options = {:action => 'show'}
    mock_controller = mock()
    mock_controller.expects(:url_for).with(options).returns('/show')
    @session.stubs(:controller).returns(mock_controller)
    assert_equal '/show', @session.url_for(options)
  end

  def test_url_for_without_controller
    options = {:action => 'show'}
    mock_rewriter = mock()
    mock_rewriter.expects(:rewrite).with(options).returns('/show')
    @session.stubs(:generic_url_rewriter).returns(mock_rewriter)
    @session.stubs(:controller).returns(nil)
    assert_equal '/show', @session.url_for(options)
  end

  def test_redirect_bool_with_status_in_300s
    @session.stubs(:status).returns 301
    assert @session.redirect?
  end

  def test_redirect_bool_with_status_in_200s
    @session.stubs(:status).returns 200
    assert !@session.redirect?
  end

  def test_get
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:get,path,params,headers)
    @session.get(path,params,headers)
  end

  def test_post
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:post,path,params,headers)
    @session.post(path,params,headers)
  end

  def test_put
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:put,path,params,headers)
    @session.put(path,params,headers)
  end

  def test_delete
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:delete,path,params,headers)
    @session.delete(path,params,headers)
  end

  def test_head
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    @session.expects(:process).with(:head,path,params,headers)
    @session.head(path,params,headers)
  end

  def test_xml_http_request_deprecated_call
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "X-Requested-With" => "XMLHttpRequest",
      "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:post,path,params,headers_after_xhr)
    assert_deprecated { @session.xml_http_request(path,params,headers) }
  end

  def test_xml_http_request_get
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "X-Requested-With" => "XMLHttpRequest",
      "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:get,path,params,headers_after_xhr)
    @session.xml_http_request(:get,path,params,headers)
  end

  def test_xml_http_request_post
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "X-Requested-With" => "XMLHttpRequest",
      "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:post,path,params,headers_after_xhr)
    @session.xml_http_request(:post,path,params,headers)
  end

  def test_xml_http_request_put
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "X-Requested-With" => "XMLHttpRequest",
      "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:put,path,params,headers_after_xhr)
    @session.xml_http_request(:put,path,params,headers)
  end

  def test_xml_http_request_delete
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "X-Requested-With" => "XMLHttpRequest",
      "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:delete,path,params,headers_after_xhr)
    @session.xml_http_request(:delete,path,params,headers)
  end

  def test_xml_http_request_head
    path = "/index"; params = "blah"; headers = {:location => 'blah'}
    headers_after_xhr = headers.merge(
      "X-Requested-With" => "XMLHttpRequest",
      "Accept"           => "text/javascript, text/html, application/xml, text/xml, */*"
    )
    @session.expects(:process).with(:head,path,params,headers_after_xhr)
    @session.xml_http_request(:head,path,params,headers)
  end
end

class IntegrationTestTest < Test::Unit::TestCase

  def setup
    @test = ::ActionController::IntegrationTest.new(:default_test)
    @test.class.stubs(:fixture_table_names).returns([])
    @session = @test.open_session
  end

  def test_opens_new_session
    @test.class.expects(:fixture_table_names).times(2).returns(['foo'])

    session1 = @test.open_session { |sess| }
    session2 = @test.open_session # implicit session

    assert_equal ::ActionController::Integration::Session, session1.class
    assert_equal ::ActionController::Integration::Session, session2.class
    assert_not_equal session1, session2
  end

end

# Tests that integration tests don't call Controller test methods for processing.
# Integration tests have their own setup and teardown.
class IntegrationTestUsesCorrectClass < ActionController::IntegrationTest

  def self.fixture_table_names
    []
  end

  def test_integration_methods_called
    %w( get post head put delete ).each do |verb|
      assert_nothing_raised("'#{verb}' should use integration test methods") { send(verb, '/') }
    end
  end

end

# TODO
# class MockCGITest < Test::Unit::TestCase
# end

end # uses_mocha
