# frozen_string_literal: true

# :markup: markdown

module ActionText
  module Attachments
    # DEPRECATED
    module Minification
      extend ActiveSupport::Concern

      class_methods do
        def fragment_by_minifying_attachments(content)
          RichText.editors.fetch(:trix).fragment_by_minifying_attachments(content)
        end
        deprecate :fragment_by_minifying_attachments, deprecator: ActionText.deprecator
      end
    end
  end
end
