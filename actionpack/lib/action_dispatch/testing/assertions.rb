module ActionDispatch
  module Assertions
    autoload :DomAssertions, 'action_dispatch/testing/assertions/dom'
    autoload :ModelAssertions, 'action_dispatch/testing/assertions/model'
    autoload :ResponseAssertions, 'action_dispatch/testing/assertions/response'
    autoload :RoutingAssertions, 'action_dispatch/testing/assertions/routing'
    autoload :SelectorAssertions, 'action_dispatch/testing/assertions/selector'
    autoload :TagAssertions, 'action_dispatch/testing/assertions/tag'

    extend ActiveSupport::Concern

    included do
      include DomAssertions
      include ModelAssertions
      include ResponseAssertions
      include RoutingAssertions
      include SelectorAssertions
      include TagAssertions
    end
  end
end
