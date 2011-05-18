require 'abstract_unit'
require 'controller/fake_models'
require 'pathname'
require 'coffee_script'
# require File.expand_path '../../lib/sprockets/handlers/coffee_script'
require 'sprockets/handlers/coffee_script'

class RenderCoffeeTest < ActionController::TestCase
  class TestController < ActionController::Base
    protect_from_forgery

    def self.controller_path
      'test'
    end

    def render_coffee_file
    end
  end

  tests TestController

  def test_should_render_coffee_file
    xhr :get, :render_coffee_file
    assert_equal "(function() {\n  alert('hi');\n}).call(this);\n", @response.body
  end

end
