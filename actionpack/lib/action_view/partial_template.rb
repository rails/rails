module ActionView #:nodoc:
  class PartialTemplate < Template #:nodoc:
    
    attr_reader :variable_name, :object
    
    def initialize(view, partial_path, object = nil, locals = {})
      @path, @variable_name = extract_partial_name_and_path(view, partial_path)
      super(view, @path, true, locals)
      add_object_to_local_assigns!(object)

      # This is needed here in order to compile template with knowledge of 'counter'
      initialize_counter
      
      # Prepare early. This is a performance optimization for partial collections
      prepare!
    end
    
    def render
      ActionController::Base.benchmark("Rendered #{@path}", Logger::DEBUG, false) do
        @handler.render(self)
      end
    end
    
    def render_member(object)
      @locals[@counter_name] += 1
      @locals[:object] = @locals[@variable_name] = object
      
      template = render_template
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
        @locals[@variable_name] ||=
          if object.is_a?(ActionView::Base::ObjectWrapper)
            object.value
          else
            object
          end || @view.controller.instance_variable_get("@#{variable_name}")
    end
    
    def extract_partial_name_and_path(view, partial_path)
      path, partial_name = partial_pieces(view, partial_path)
      [File.join(path, "_#{partial_name}"), partial_name.split('/').last.split('.').first.to_sym] 
    end
    
    def partial_pieces(view, partial_path)
      if partial_path.include?('/')
        return File.dirname(partial_path), File.basename(partial_path)
      else
        return view.controller.class.controller_path, partial_path
      end
    end
    
    def initialize_counter
      @counter_name ||= "#{@variable_name}_counter".to_sym
      @locals[@counter_name] = 0
    end
    
  end
end
