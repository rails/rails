module ActionView #:nodoc:
  class InlineTemplate #:nodoc:
    include Renderable

    # Count the number of inline templates
    cattr_accessor :inline_template_count
    @@inline_template_count = 0

    def initialize(view, source, locals = {}, type = nil)
      @view = view

      @source = source
      @extension = type
      @locals = locals || {}

      @method_key = @source
      @handler = Template.handler_class_for_extension(@extension).new(@view)
    end

    private
      # FIXME: Modifying this shared variable may not thread safe
      def method_name_path_segment
        "inline_#{@@inline_template_count += 1}"
      end
  end
end
