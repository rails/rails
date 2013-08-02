module ActionDispatch
  module Assertions
    autoload :ResponseAssertions, 'action_dispatch/testing/assertions/response'
    autoload :RoutingAssertions, 'action_dispatch/testing/assertions/routing'

    extend ActiveSupport::Concern

    include ResponseAssertions
    include RoutingAssertions
  end
end

