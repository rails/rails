# encoding: utf-8

module I18n
  module Backend
    # Backend that chains multiple other backends and checks each of them when
    # a translation needs to be looked up. This is useful when you want to use
    # standard translations with a Simple backend but store custom application
    # translations in a database or other backends.
    #
    # To use the Chain backend instantiate it and set it to the I18n module.
    # You can add chained backends through the initializer or backends
    # accessor:
    #
    #   # preserves the existing Simple backend set to I18n.backend
    #   I18n.backend = I18n::Backend::Chain.new(I18n::Backend::ActiveRecord.new, I18n.backend)
    #
    # The implementation assumes that all backends added to the Chain implement
    # a lookup method with the same API as Simple backend does.
    class Chain
      include Base

      attr_accessor :backends

      def initialize(*backends)
        self.backends = backends
      end

      def reload!
        backends.each { |backend| backend.reload! }
      end

      def store_translations(locale, data, options = {})
        backends.first.store_translations(locale, data, options = {})
      end

      def available_locales
        backends.map { |backend| backend.available_locales }.flatten.uniq
      end

      def translate(locale, key, options = {})
        return key.map { |k| translate(locale, k, options) } if key.is_a?(Array)

        default = options.delete(:default)
        namespace = {}
        backends.each do |backend|
          begin
            options.update(:default => default) if default and backend == backends.last
            translation = backend.translate(locale, key, options)
            if namespace_lookup?(translation, options)
              namespace.update(translation)
            elsif !translation.nil?
              return translation
            end
          rescue MissingTranslationData
          end
        end
        return namespace unless namespace.empty?
        raise(I18n::MissingTranslationData.new(locale, key, options))
      end

      def localize(locale, object, format = :default, options = {})
        backends.each do |backend|
          begin
            result = backend.localize(locale, object, format, options) and return result
          rescue MissingTranslationData
          end
        end
        raise(I18n::MissingTranslationData.new(locale, format, options))
      end

      protected
        def namespace_lookup?(result, options)
          result.is_a?(Hash) and not options.has_key?(:count)
        end
    end
  end
end
