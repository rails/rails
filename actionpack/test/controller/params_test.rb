require "abstract_unit"

class ParamsTest < ActionDispatch::IntegrationTest
  class TestController < ActionController::Base
    def params_test ; end
  end

  def setup
    @controller = TestController.new
  end

  def test_post_params
    with_test_route_set do
      post "/", {"username" => "david"}
      assert_equal "david", @controller.params[:username]
      assert_nil @controller.params[:baz]
    end
  end

  def test_route_params
    with_test_route_set do
      get "/bar"
      assert_equal "bar", @controller.params[:foo]
    end
  end

  def test_nested_params
    with_test_route_set do
      post "/", {"user" => {"username" => "guille"}}
      assert_equal "guille", @controller.params[:user][:username]
      assert_nil @controller.params[:user][:baz]
    end
  end

  def test_param
    with_test_route_set do
      post "/", {"user" => {"username" => "gorbachev"}}
      assert_equal "gorbachev", @controller.param("user.username")
      assert_nil @controller.param("user.baz")
    end
  end

  private
    def with_test_route_set
      with_routing do |set|
        set.draw do
          match '/', :to => 'params_test/test#params_test'
          match '/:foo', :to => 'params_test/test#params_test'
        end
        yield
      end
    end
end
