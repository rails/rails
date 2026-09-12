# frozen_string_literal: true

module ActiveStorage
  module Reflection
    module Extensions
      extend ActiveSupport::Concern

      included do
        class_attribute :attachment_reflections, instance_writer: false, default: {}
      end

      module ClassMethods
        # Returns an array of reflection objects for all the attachments in the
        # class.
        def reflect_on_all_attachments
          attachment_reflections.values
        end

        # Returns the reflection object for the named +attachment+.
        #
        #    User.reflect_on_attachment(:avatar)
        #    # => the avatar reflection
        #
        def reflect_on_attachment(attachment)
          attachment_reflections[attachment.to_s]
        end
      end
    end

    class ActiveModelHasAttachedReflection # :nodoc:
      attr_reader :active_record, :name, :options

      def initialize(active_record, name, options)
        @active_record = active_record
        @name = name
        @options = options
      end

      def variant(name, transformations)
        named_variants[name] = ActiveStorage::NamedVariant.new(transformations)
      end

      def named_variants
        @named_variants ||= {}
      end

      def macro
        raise NotImplementedError
      end
    end

    # Holds all the metadata about a has_one_attached attachment as it was
    # specified in an Active Model class.
    class ActiveModelHasOneAttachedReflection < ActiveModelHasAttachedReflection # :nodoc:
      def macro
        :has_one_attached
      end
    end

    # Holds all the metadata about a has_many_attached attachment as it was
    # specified in an Active Model class.
    class ActiveModelHasManyAttachedReflection < ActiveModelHasAttachedReflection # :nodoc:
      def macro
        :has_many_attached
      end
    end
  end
end
