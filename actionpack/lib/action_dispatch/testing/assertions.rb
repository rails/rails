module ActionDispatch
  module Assertions
    autoload :DomAssertions, 'action_dispatch/testing/assertions/dom'
    autoload :ResponseAssertions, 'action_dispatch/testing/assertions/response'
    autoload :RoutingAssertions, 'action_dispatch/testing/assertions/routing'
    autoload :SelectorAssertions, 'action_dispatch/testing/assertions/selector'

    extend ActiveSupport::Concern

    include DomAssertions
    include ResponseAssertions
    include RoutingAssertions
    include SelectorAssertions
  end
end

