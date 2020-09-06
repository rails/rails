# frozen_string_literal: true

require 'abstract_unit'
require 'active_support/core_ext/integer/time'
require 'active_support/core_ext/numeric/time'

class ConditionalGetApiController < ActionController::API
  before_action :handle_last_modified_and_etags, only: :two

  def one
    if stale?(last_modified: Time.now.utc.beginning_of_day, etag: [:foo, 123])
      render plain: 'Hi!'
    end
  end

  def two
    render plain: 'Hi!'
  end

  private
    def handle_last_modified_and_etags
      fresh_when(last_modified: Time.now.utc.beginning_of_day, etag: [ :foo, 123 ])
    end
end

class ConditionalGetApiTest < ActionController::TestCase
  tests ConditionalGetApiController

  def setup
    @last_modified = Time.now.utc.beginning_of_day.httpdate
  end

  def test_request_gets_last_modified
    get :two
    assert_equal @last_modified, @response.headers['Last-Modified']
    assert_response :success
  end

  def test_request_obeys_last_modified
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
    assert_predicate @response.body, :blank?
    assert_equal @last_modified, @response.headers['Last-Modified']
  end
end
