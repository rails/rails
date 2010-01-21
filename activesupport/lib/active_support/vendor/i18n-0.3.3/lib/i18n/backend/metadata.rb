# I18n translation metadata is useful when you want to access information
# about how a translation was looked up, pluralized or interpolated in
# your application.
#
#   msg = I18n.t(:message, :default => 'Hi!', :scope => :foo)
#   msg.translation_metadata
#   # => { :key => :message, :scope => :foo, :default => 'Hi!' }
#
# If a :count option was passed to #translate it will be set to the metadata.
# Likewise, if any interpolation variables were passed they will also be set.
#
# To enable translation metadata you can simply include the Metadata module
# into the Simple backend class - or whatever other backend you are using:
#
#   I18n::Backend::Simple.send(:include, I18n::Backend::Metadata)

require 'i18n/core_ext/object/meta_class'

module I18n
  module Backend
    module Metadata
      class << self
        def included(base)
          Object.class_eval do
            def translation_metadata
              @translation_metadata ||= {}
            end

            def translation_metadata=(translation_metadata)
              @translation_metadata = translation_metadata
            end
          end
        end
      end

      def translate(locale, key, options = {})
        metadata = {
          :locale    => locale,
          :key       => key,
          :scope     => options[:scope],
          :default   => options[:default],
          :separator => options[:separator],
          :values    => options.reject { |name, value| Base::RESERVED_KEYS.include?(name) }
        }
        with_metadata(metadata) { super }
      end

      def interpolate(locale, string, values = {})
        with_metadata(:original => string) do
          preserve_translation_metadata(string) { super }
        end if string
      end

      def pluralize(locale, entry, count)
        with_metadata(:count => count) { super }
      end

      protected

        def with_metadata(metadata, &block)
          result = yield
          result.translation_metadata = result.translation_metadata.merge(metadata) if result
          result
        end

        def preserve_translation_metadata(object, &block)
          result = yield
          result.translation_metadata = object.translation_metadata if result
          result
        end
    end
  end
end
