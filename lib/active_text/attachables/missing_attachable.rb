module ActiveText
  module Attachables
    module MissingAttachable
      extend ActiveModel::Naming

      def self.to_partial_path
        "active_text/attachables/missing_attachable"
      end
    end
  end
end
