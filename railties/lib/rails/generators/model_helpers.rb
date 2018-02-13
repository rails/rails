# frozen_string_literal: true

require "rails/generators/active_model"

module Rails
  module Generators
    module ModelHelpers # :nodoc:
      PLURAL_MODEL_NAME_WARN_MESSAGE = "[WARNING] The model name '%s' was recognized as a plural, using the singular '%s' instead. " \
                                       "Override with --force-plural or setup custom inflection rules for this noun before running the generator."
      mattr_accessor :skip_warn

      def self.included(base) #:nodoc:
        base.class_option :force_plural, type: :boolean, default: false, desc: "Forces the use of the given model name"
      end

      def initialize(args, *_options)
        super
        if name == name.pluralize && name.singularize != name.pluralize && !options[:force_plural]
          singular = name.singularize
          unless ModelHelpers.skip_warn
            say PLURAL_MODEL_NAME_WARN_MESSAGE % [name, singular]
            ModelHelpers.skip_warn = true
          end
          name.replace singular
          assign_names!(name)
        end
      end
    end
  end
end
