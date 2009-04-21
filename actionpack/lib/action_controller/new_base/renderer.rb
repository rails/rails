module ActionController
  module Renderer
    depends_on AbstractController::Renderer
    
    def initialize(*)
      self.formats = [:html]
      super
    end
    
    def render(action, options = {})
      # TODO: Move this into #render_to_body
      if action.is_a?(Hash)
        options, action = action, nil 
      else
        options.merge! :action => action
      end
      
      _process_options(options)
      
      self.response_body = render_to_body(options)
    end

    def render_to_body(options)
      unless options.is_a?(Hash)
        options = {:action => options}
      end

      if options.key?(:text)
        options[:_template] = ActionView::TextTemplate.new(_text(options))
        template = nil
      elsif options.key?(:template)
        options[:_template_name] = options[:template]
      elsif options.key?(:action)
        options[:_template_name] = options[:action].to_s
        options[:_prefix] = _prefix 
      end
      
      super(options)
    end
    
  private
  
    def _prefix
      controller_path
    end  
  
    def _text(options)
      text = options[:text]

      case text
      when nil then " "
      else text.to_s
      end
    end
  
    def _process_options(options)
      if status = options[:status]
        response.status = status.to_i
      end
    end
  end
end
