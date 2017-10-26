# frozen_string_literal: true

module ActionDispatch
  module SystemTesting
    module TestHelpers
      module UndefMethods # :nodoc:
        extend ActiveSupport::Concern
        included do
          METHODS = %i(get post put patch delete).freeze

          METHODS.each do |verb|
            undef_method verb
          end

          def method_missing(method, *args, &block)
            if METHODS.include?(method)
              raise NoMethodError, "System tests cannot make direct requests via ##{method}; use #visit and #click_on instead. See http://www.rubydoc.info/github/teamcapybara/capybara/master#The_DSL for more information."
            else
              super
            end
          end
        end
      end
    end
  end
end
