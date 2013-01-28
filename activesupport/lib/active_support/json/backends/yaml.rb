require 'active_support/core_ext/string/starts_ends_with'

module ActiveSupport
  module JSON
    module Backends
      module Yaml
        ParseError = ::StandardError
        extend self

        def decode(json)
          raise "The Yaml backend has been deprecated due to security risks, you should set ActiveSupport::JSON.backend = 'OkJson'"
        end

        protected

      end
    end
  end
end

