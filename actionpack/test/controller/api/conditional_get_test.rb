# frozen_string_literal: true

require "abstract_unit"
require "active_support/core_ext/integer/time"
require "active_support/core_ext/numeric/time"
require "support/etag_helper"

class ConditionalGetApiController < ActionController::API
  before_action :handle_last_modified_and_etags, only: :two

  def one
    if stale?(last_modified: Time.now.utc.beginning_of_day, etag: [:foo, 123])
      render plain: "Hi!"
    end
  end

  def two
    render plain: "Hi!"
  end

  private
    def handle_last_modified_and_etags
      fresh_when(last_modified: Time.now.utc.beginning_of_day, etag: [ :foo, 123 ])
    end
end

class ConditionalGetApiTest < ActionController::TestCase
  include EtagHelper
  tests ConditionalGetApiController

  def setup
    @last_modified = Time.now.utc.beginning_of_day.httpdate
  end

  def test_request_gets_last_modified
    get :two
    assert_equal @last_modified, @response.headers["Last-Modified"]
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
    assert_equal @last_modified, @response.headers["Last-Modified"]
  end

  def test_if_none_match_is_asterisk
    @request.if_none_match = "*"
    get :one
    assert_response :not_modified
  end

  def test_etag_matches
    @request.if_none_match = weak_etag([:foo, 123])
    get :one
    assert_response :not_modified
  end

  def test_strict_freshness_with_etag
    with_strict_freshness(true) do
      @request.if_none_match = weak_etag([:foo, 123])

      get :one
      assert_response :not_modified
    end
  end

  def test_strict_freshness_with_last_modified
    with_strict_freshness(true) do
      @request.if_modified_since = @last_modified

      get :one
      assert_response :not_modified
    end
  end

  def test_strict_freshness_etag_precedence_over_last_modified
    with_strict_freshness(true) do
      # Not modified because the etag matches
      @request.if_modified_since = 5.years.ago.httpdate
      @request.if_none_match = weak_etag([:foo, 123])

      get :one
      assert_response :not_modified

      # stale because the etag doesn't match
      @request.if_none_match = weak_etag([:bar, 124])
      @request.if_modified_since = @last_modified

      get :one
      assert_response :success
    end
  end

  def test_both_should_be_used_when_strict_freshness_is_false
    with_strict_freshness(false) do
      # stale because the etag match but the last modified doesn't
      @request.if_modified_since = 5.years.ago.httpdate
      @request.if_none_match = weak_etag([:foo, 123])

      get :one
      assert_response :ok
    end
  end

  private
    def with_strict_freshness(value)
      old_value = ActionDispatch::Http::Cache::Request.strict_freshness
      ActionDispatch::Http::Cache::Request.strict_freshness = value
      yield
    ensure
      ActionDispatch::Http::Cache::Request.strict_freshness = old_value
    end
end
