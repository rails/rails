require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    module TranslationHelper
      def translate(*args)
        args << args.extract_options!.merge(:raise => true)
        I18n.translate *args

      rescue I18n::MissingTranslationData => e
        keys = I18n.send :normalize_translation_keys, e.locale, e.key, e.options[:scope]
        content_tag('span', keys.join(', '), :class => 'translation_missing')
      end
      alias :t :translate

      def localize(*args)
        I18n.localize *args
      end
      alias :l :localize
    end
  end
end