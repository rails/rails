require 'loofah'

module ActionView
  module Assertions
    autoload :DomAssertions, 'action_view/testing/assertions/dom'
    autoload :SelectorAssertions, 'action_view/testing/assertions/selector'

    extend ActiveSupport::Concern

    include DomAssertions
    include SelectorAssertions
  end
end