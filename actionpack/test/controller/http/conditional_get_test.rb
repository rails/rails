require 'abstract_unit'

class ConditionalGetHTTPController < ActionController::HTTP
  before_filter :handle_last_modified_and_etags, :only => :two

  def one
    if stale?(:last_modified => Time.now.utc.beginning_of_day, :etag => [:foo, 123])
      render :text => "Hi!"
    end
  end

  def two
    render :text => "Hi!"
  end

  private

  def handle_last_modified_and_etags
    fresh_when(:last_modified => Time.now.utc.beginning_of_day, :etag => [ :foo, 123 ])
  end
end

class ConditionalGetHTTPTest < ActionController::TestCase
  tests ConditionalGetHTTPController

  def setup
    @last_modified = Time.now.utc.beginning_of_day.httpdate
  end

  def test_request_with_bang_gets_last_modified
    get :two
    assert_equal @last_modified, @response.headers['Last-Modified']
    assert_response :success
  end

  def test_request_with_bang_obeys_last_modified
    @request.if_modified_since = @last_modified
    get :two
    assert_response :not_modified
  end

  def test_last_modified_works_with_less_than_too
    @request.if_modified_since = 5.years.ago.httpdate
    get :two
    assert_response :success
  end

  def test_request_not_modified
    @request.if_modified_since = @last_modified
    get :one
    assert_equal 304, @response.status.to_i
    assert_blank @response.body
    assert_equal @last_modified, @response.headers['Last-Modified']
  end
end
