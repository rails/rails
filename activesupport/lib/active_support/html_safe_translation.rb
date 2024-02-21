# frozen_string_literal: true

module ActiveSupport
  module HtmlSafeTranslation # :nodoc:
    extend self

    def translate(key, **options)
      if html_safe_translation_key?(key)
        html_safe_options = html_escape_translation_options(options)

        exception = false
        exception_handler = ->(*args) do
          exception = true
          I18n.exception_handler.call(*args)
        end
        translation = I18n.translate(key, **html_safe_options, exception_handler: exception_handler)
        if exception
          translation
        else
          html_safe_translation(translation)
        end
      else
        I18n.translate(key, **options)
      end
    end

    private
      def html_safe_translation_key?(key)
        /(?:_|\b)html\z/.match?(key)
      end

      def html_escape_translation_options(options)
        options.each do |name, value|
          unless i18n_option?(name) || (name == :count && value.is_a?(Numeric))
            options[name] = ERB::Util.html_escape(value.to_s)
          end
        end
      end

      def i18n_option?(name)
        (@i18n_option_names ||= I18n::RESERVED_KEYS.to_set).include?(name)
      end


      def html_safe_translation(translation)
        if translation.respond_to?(:map)
          translation.map { |element| element.respond_to?(:html_safe) ? element.html_safe : element }
        else
          translation.respond_to?(:html_safe) ? translation.html_safe : translation
        end
      end
  end
end
