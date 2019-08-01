# frozen_string_literal: true

module ActiveSupport
  module Testing
    module AlternativeRuntimeSkipper
      private
        # Skips the current run on Rubinius using Minitest::Assertions#skip
        def rubinius_skip(message = "")
          skip message if RUBY_ENGINE == "rbx"
        end

        # Skips the current run on JRuby using Minitest::Assertions#skip
        def jruby_skip(message = "")
          skip message if defined?(JRUBY_VERSION)
        end
    end
  end
end
