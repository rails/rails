module ActionView #:nodoc:
  class PartialTemplate < Template #:nodoc:
    attr_reader :variable_name, :object, :as

    def initialize(view, partial_path, object = nil, locals = {}, as = nil)
      @view_controller = view.controller if view.respond_to?(:controller)
      @as = as
      set_path_and_variable_name!(partial_path)
      super(view, @path, nil, locals)
      add_object_to_local_assigns!(object)

      # This is needed here in order to compile template with knowledge of 'counter'
      initialize_counter!

      # Prepare early. This is a performance optimization for partial collections
      prepare!
    end

    def render
      ActionController::Base.benchmark("Rendered #{@path.path_without_format_and_extension}", Logger::DEBUG, false) do
        super
      end
    end

    def render_member(object)
      @locals[:object] = @locals[@variable_name] = object
      @locals[as] = object if as

      template = render_template
      @locals[@counter_name] += 1
      @locals.delete(as)
      @locals.delete(@variable_name)
      @locals.delete(:object)

      template
    end

    def counter=(num)
      @locals[@counter_name] = num
    end

    private
      def add_object_to_local_assigns!(object)
        @locals[:object] ||=
          @locals[@variable_name] ||= object || @view_controller.instance_variable_get("@#{variable_name}")
        @locals[as] ||= @locals[:object] if as
      end

      def set_path_and_variable_name!(partial_path)
        if partial_path.include?('/')
          @variable_name = File.basename(partial_path)
          @path = "#{File.dirname(partial_path)}/_#{@variable_name}"
        elsif @view_controller
          @variable_name = partial_path
          @path = "#{@view_controller.class.controller_path}/_#{@variable_name}"
        else
          @variable_name = partial_path
          @path = "_#{@variable_name}"
        end

        @variable_name = @variable_name.sub(/\..*$/, '').to_sym
      end

      def initialize_counter!
        @counter_name ||= "#{@variable_name}_counter".to_sym
        @locals[@counter_name] = 0
      end
  end
end
