require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    module TranslationHelper
      def translate(*args)
        key, locale, options = I18n.send :process_translate_arguments, *args
        I18n.translate key, locale, options.merge(:raise => true)

      rescue I18n::MissingTranslationData => e
        keys = I18n.send :normalize_translation_keys, locale, key, options[:scope]
        content_tag('span', keys.join(', '), :class => 'translation_missing')
      end
    end
  end
end