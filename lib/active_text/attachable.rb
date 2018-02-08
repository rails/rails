module ActiveText
  module Attachable
    class << self
      def from_node(node)
        if attachable = attachable_from_sgid(node["sgid"])
          attachable
        elsif attachable = ActiveText::Attachables::ContentAttachment.from_node(node)
          attachable
        elsif attachable = ActiveText::Attachables::RemoteImage.from_node(node)
          attachable
        else
          ActiveText::Attachables::MissingAttachable
        end
      end

      private
        def attachable_from_sgid(sgid)
          ::Attachable.from_attachable_sgid(sgid)
        rescue ActiveRecord::RecordNotFound
          nil
        end
    end
  end
end
