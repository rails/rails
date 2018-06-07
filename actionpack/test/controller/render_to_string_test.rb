# frozen_string_literal: true

require "abstract_unit"
require "controller/fake_models"
require "active_support/logger"
require "pathname"
require "byebug"

class RenderToStringTest < ActionController::TestCase
  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      "test"
    end

    def render_file_with_ivar
      @secret = "world"
      json_as_string = render_to_string(formats: [:json], layout: false)
      @secret = JSON.parse(json_as_string)["secret"]
    end
  end

  tests TestController

  def setup
    # enable a logger so that (e.g.) the benchmarking stuff runs, so we can get
    # a more accurate simulation of what happens in "real life".
    super
    @controller.logger = ActiveSupport::Logger.new(nil)

    @request.host = "www.nextangle.com"
  end

  def test_render_with_previous_render_to_string
    get :render_file_with_ivar
    assert_equal "The secret is hello world!", @response.body.strip
    assert_equal "text/html", @response.content_type
  end
end
