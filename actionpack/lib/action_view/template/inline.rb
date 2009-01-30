module ActionView #:nodoc:
  class InlineTemplate #:nodoc:
    include Renderable

    attr_reader :source, :extension, :method_segment

    def initialize(source, type = nil)
      @source = source
      @extension = type
      @method_segment = "inline_#{@source.hash.abs}"
    end

    private
      # Always recompile inline templates
      def recompile?
        true
      end
  end
end
