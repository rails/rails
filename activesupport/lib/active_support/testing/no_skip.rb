# frozen_string_literal: true

module ActiveSupport
  module Testing
    module NoSkip # :nodoc:
      private
        def skip(message = nil, *)
          flunk "Skipping tests is not allowed in this environment (#{message})\n" \
            "Tests should only be skipped when the environment is missing a required dependency.\n" \
            "This should never happen on CI."
        end
    end
  end
end
