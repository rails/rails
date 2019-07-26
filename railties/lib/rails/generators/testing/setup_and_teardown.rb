# frozen_string_literal: true

module Rails
  module Generators
    module Testing
      module SetupAndTeardown
        def setup # :nodoc:
          destination_root_is_set?
          ensure_current_path
          super
        end

        def teardown # :nodoc:
          ensure_current_path
          super
        end
      end
    end
  end
end
