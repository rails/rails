# frozen_string_literal: true

# :markup: markdown

module ActionText
  module Attachables
    class MissingAttachable
      extend ActiveModel::Naming

      DEFAULT_PARTIAL_PATH = "action_text/attachables/missing_attachable"

      def initialize(sgid)
        @sgid = SignedGlobalID.parse(sgid, for: ActionText::Attachable::LOCATOR_NAME)
      end

      def to_partial_path
        if model
          model.to_missing_attachable_partial_path
        else
          DEFAULT_PARTIAL_PATH
        end
      end

      def attachable_plain_text_representation(caption = nil)
        "☒"
      end

      def attachable_markdown_representation(caption = nil)
        "☒"
      end

      def model
        @sgid&.model_name.to_s.safe_constantize
      end
    end
  end
end
