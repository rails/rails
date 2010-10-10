require 'digest/md5'

module ActionView
  class Template
    class Inline < ::ActionView::Template
      def initialize(source, handler, options={})
        super(source, "inline template", handler, options)
      end

      def md5_source
        @md5_source ||= Digest::MD5.hexdigest(source)
      end

      def eql?(other)
        other.is_a?(Inline) && other.md5_source == md5_source
      end
    end
  end
end
    