module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module Pathname #:nodoc:
      module CleanWithin
        # Clean the paths contained in the provided string.
        def clean_within(string)
          string.gsub(%r{[\w. ]+(/[\w. ]+)+(\.rb)?(\b|$)}) do |path|
            new(path).cleanpath
          end
        end
      end
    end
  end
end
