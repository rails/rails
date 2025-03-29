# frozen_string_literal: true

require "abstract_unit"

class ConditionalGetDirectivesController < ActionController::Base
  def must_understand_action
    must_understand
    render plain: "using must-understand directive"
  end

  def cache_control_with_must_understand
    fresh_when etag: "123", cache_control: { must_understand: true }
    render plain: "with must-understand via cache_control" unless performed?
  end

  def must_understand_without_no_store
    response.cache_control[:no_cache] = true
    response.cache_control[:must_understand] = true
    render plain: "no-cache with must-understand"
  end
end

class ConditionalGetDirectivesTest < ActionController::TestCase
  tests ConditionalGetDirectivesController

  def test_must_understand
    get :must_understand_action
    assert_response :success
    assert_includes @response.headers["Cache-Control"], "must-understand"
  end

  def test_cache_control_with_must_understand
    get :cache_control_with_must_understand
    assert_response :success
    assert_not_includes @response.headers["Cache-Control"], "must-understand"
  end

  def test_must_understand_without_no_store
    get :must_understand_without_no_store
    assert_response :success
    assert_not_includes @response.headers["Cache-Control"], "must-understand"
    assert_includes @response.headers["Cache-Control"], "no-cache"
  end
end
