require 'parsedate'

module ActiveSupport #:nodoc:
  module CoreExtensions #:nodoc:
    module String #:nodoc:
      # Converting strings to other objects
      module Conversions
        # Form can be either :utc (default) or :local.
        def to_time(form = :utc)
          ::Time.send(form, *ParseDate.parsedate(self))
        end

        def to_date
          ::Date.new(*ParseDate.parsedate(self)[0..2])
        end
      end
    end
  end
end