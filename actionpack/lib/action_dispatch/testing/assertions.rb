module ActionDispatch
  module Assertions
    %w(response selector tag dom routing model).each do |kind|
      require "action_dispatch/testing/assertions/#{kind}"
      include const_get("#{kind.camelize}Assertions")
    end
  end
end
