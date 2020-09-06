# frozen_string_literal: true

require 'rails/generators/named_base'

module Erb # :nodoc:
  module Generators # :nodoc:
    class Base < Rails::Generators::NamedBase #:nodoc:
      private
        def formats
          [format]
        end

        def format
          :html
        end

        def handler
          :erb
        end

        def filename_with_extensions(name, file_format = format)
          [name, file_format, handler].compact.join('.')
        end
    end
  end
end
