# frozen_string_literal: true

require "abstract_unit"

class RouteHelperIntegrationTest < ActionDispatch::IntegrationTest
  class FooController < ApplicationController
  end

  # We define many routes in these modules after they have been included into
  # the controllers. For boot performance, it's important that we don't
  # duplicate these modules and make method cache invalidation expensive.
  # https://github.com/rails/rails/pull/37927
  test "only includes one module with route helpers" do
    url_helpers_module = SharedTestRoutes.named_routes.url_helpers_module
    path_helpers_module = SharedTestRoutes.named_routes.path_helpers_module

    assert_operator FooController, :<, url_helpers_module
    assert_operator ApplicationController, :<, url_helpers_module
    assert_not_operator ActionController::Base, :<, url_helpers_module

    assert_operator FooController, :<, path_helpers_module
    assert_operator ApplicationController, :<, path_helpers_module
    assert_not_operator ActionController::Base, :<, path_helpers_module

    included_modules = FooController.ancestors.grep_v(Class)
    included_modules -= [url_helpers_module, path_helpers_module]

    modules_with_routes = included_modules.select do |mod|
      mod < url_helpers_module || mod < path_helpers_module
    end

    assert_equal 1, modules_with_routes.size
  end
end
