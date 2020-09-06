# frozen_string_literal: true

module ActionText
  module Attachables
    module MissingAttachable
      extend ActiveModel::Naming

      def self.to_partial_path
        'action_text/attachables/missing_attachable'
      end
    end
  end
end
