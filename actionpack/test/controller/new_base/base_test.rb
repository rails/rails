# frozen_string_literal: true

require "abstract_unit"

# Tests the controller dispatching happy path
module Dispatching
  class SimpleController < ActionController::Base
    before_action :authenticate

    def index
      render body: "success"
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
      render body: "actions: #{action_methods.to_a.sort.join(', ')}"
    end

    private
      def authenticate
      end
  end

  class EmptyController < ActionController::Base ; end
  class SubEmptyController < EmptyController ; end
  class NonDefaultPathController < ActionController::Base
    def self.controller_path; "i_am_not_default"; end
  end

  module Submodule
    class ContainedEmptyController < ActionController::Base ; end
    class ContainedSubEmptyController < ContainedEmptyController ; end
    class ContainedNonDefaultPathController < ActionController::Base
      def self.controller_path; "i_am_extremely_not_default"; end
    end
  end

  class BaseTest < Rack::TestCase
    test "simple dispatching" do
      get "/dispatching/simple/index"

      assert_body "success"
      assert_status 200
      assert_content_type "text/plain; charset=utf-8"
    end

    test "directly modifying response body" do
      get "/dispatching/simple/modify_response_body"

      assert_body "success"
    end

    test "directly modifying response body twice" do
      get "/dispatching/simple/modify_response_body_twice"

      assert_body "success!"
    end

    test "controller path" do
      assert_equal "dispatching/empty", EmptyController.controller_path
      assert_equal EmptyController.controller_path, EmptyController.new.controller_path
    end

    test "non-default controller path" do
      assert_equal "i_am_not_default", NonDefaultPathController.controller_path
      assert_equal NonDefaultPathController.controller_path, NonDefaultPathController.new.controller_path
    end

    test "sub controller path" do
      assert_equal "dispatching/sub_empty", SubEmptyController.controller_path
      assert_equal SubEmptyController.controller_path, SubEmptyController.new.controller_path
    end

    test "namespaced controller path" do
      assert_equal "dispatching/submodule/contained_empty", Submodule::ContainedEmptyController.controller_path
      assert_equal Submodule::ContainedEmptyController.controller_path, Submodule::ContainedEmptyController.new.controller_path
    end

    test "namespaced non-default controller path" do
      assert_equal "i_am_extremely_not_default", Submodule::ContainedNonDefaultPathController.controller_path
      assert_equal Submodule::ContainedNonDefaultPathController.controller_path, Submodule::ContainedNonDefaultPathController.new.controller_path
    end

    test "namespaced sub controller path" do
      assert_equal "dispatching/submodule/contained_sub_empty", Submodule::ContainedSubEmptyController.controller_path
      assert_equal Submodule::ContainedSubEmptyController.controller_path, Submodule::ContainedSubEmptyController.new.controller_path
    end

    test "controller name" do
      assert_equal "empty", EmptyController.controller_name
      assert_equal "contained_empty", Submodule::ContainedEmptyController.controller_name
    end

    test "non-default path controller name" do
      assert_equal "non_default_path", NonDefaultPathController.controller_name
      assert_equal "contained_non_default_path", Submodule::ContainedNonDefaultPathController.controller_name
    end

    test "sub controller name" do
      assert_equal "sub_empty", SubEmptyController.controller_name
      assert_equal "contained_sub_empty", Submodule::ContainedSubEmptyController.controller_name
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
