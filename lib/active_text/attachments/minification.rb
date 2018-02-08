module ActiveText
  module Attachments
    module Minification
      extend ActiveSupport::Concern

      class_methods do
        def fragment_by_minifying_attachments(content)
          Fragment.wrap(content).replace(ActiveText::Attachment::SELECTOR) do |node|
            node.tap { |node| node.inner_html = "" }
          end
        end
      end
    end
  end
end
