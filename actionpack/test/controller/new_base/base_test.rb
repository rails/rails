require 'abstract_unit'

# Tests the controller dispatching happy path
module Dispatching
  class SimpleController < ActionController::Base
    before_filter :authenticate

    def index
      render :text => "success"
    end

    def modify_response_body
      self.response_body = "success"
    end

    def modify_response_body_twice
      ret = (self.response_body = "success")
      self.response_body = "#{ret}!"
    end

    def modify_response_headers
    end

    def show_actions
      render :text => "actions: #{action_methods.to_a.sort.join(', ')}"
    end

    protected
      def authenticate
      end
  end

  class EmptyController < ActionController::Base ; end

  module Submodule
    class ContainedEmptyController < ActionController::Base ; end
  end

  class BaseTest < Rack::TestCase
    # :api: plugin
    test "simple dispatching" do
      get "/dispatching/simple/index"

      assert_body "success"
      assert_status 200
      assert_content_type "text/html; charset=utf-8"
    end

    # :api: plugin
    test "directly modifying response body" do
      get "/dispatching/simple/modify_response_body"

      assert_body "success"
    end

    # :api: plugin
    test "directly modifying response body twice" do
      get "/dispatching/simple/modify_response_body_twice"

      assert_body "success!"
    end

    test "controller path" do
      assert_equal 'dispatching/empty', EmptyController.controller_path
      assert_equal EmptyController.controller_path, EmptyController.new.controller_path
    end

    test "namespaced controller path" do
      assert_equal 'dispatching/submodule/contained_empty', Submodule::ContainedEmptyController.controller_path
      assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
    end

    test "controller name" do
      assert_equal 'empty', EmptyController.controller_name
      assert_equal 'contained_empty', Submodule::ContainedEmptyController.controller_name
    end

    test "action methods" do
      assert_equal Set.new(%w(
        index
        modify_response_headers
        modify_response_body_twice
        modify_response_body
        show_actions
      )), SimpleController.action_methods

      assert_equal Set.new, EmptyController.action_methods
      assert_equal Set.new, Submodule::ContainedEmptyController.action_methods

      get "/dispatching/simple/show_actions"
      assert_body "actions: index, modify_response_body, modify_response_body_twice, modify_response_headers, show_actions"
    end
  end
end
