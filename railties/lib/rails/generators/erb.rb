require "rails/generators/named_base"

module Erb # :nodoc:
  module Generators # :nodoc:
    class Base < Rails::Generators::NamedBase #:nodoc:
      protected

        def formats
          [format]
        end

        def format
          :html
        end

        def handler
          :erb
        end

        def filename_with_extensions(name, format = self.format)
          [name, format, handler].compact.join(".")
        end
    end
  end
end
