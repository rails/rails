# frozen_string_literal: true

module Rails
  module Generators
    module AppName # :nodoc:
      RESERVED_NAMES = %w(application destroy plugin runner test)

      private
        def app_name
          @app_name ||= original_app_name.tr('\\', "").tr("-. ", "_")
        end

        def original_app_name
          @original_app_name ||= defined_app_const_base? ? defined_app_name : File.basename(destination_root)
        end

        def defined_app_name
          defined_app_const_base.underscore
        end

        def defined_app_const_base
          Rails.respond_to?(:application) && defined?(Rails::Application) &&
            Rails.application.is_a?(Rails::Application) && Rails.application.class.name.chomp("::Application")
        end

        alias :defined_app_const_base? :defined_app_const_base

        def app_const_base
          @app_const_base ||= defined_app_const_base || app_name.gsub(/\W/, "_").squeeze("_").camelize
        end
        alias :camelized :app_const_base

        def app_const
          @app_const ||= "#{app_const_base}::Application"
        end

        def valid_const?
          if /^\d/.match?(app_const)
            raise Error, "Invalid application name #{original_app_name}. Please give a name which does not start with numbers."
          elsif RESERVED_NAMES.include?(original_app_name)
            raise Error, "Invalid application name #{original_app_name}. Please give a " \
                         "name which does not match one of the reserved rails " \
                         "words: #{RESERVED_NAMES.join(", ")}"
          elsif Object.const_defined?(app_const_base)
            raise Error, "Invalid application name #{original_app_name}, constant #{app_const_base} is already in use. Please choose another application name."
          end
        end
    end
  end
end
