module ActionController
  module Renderer
    
    def render(options)
      _process_options(options)
      
      self.response_body = render_to_string(options)
    end
    
    def render_to_string(options)
      self.formats = [:html]
      
      if options.key?(:text)
        text = options.delete(:text)

        case text
        when nil then " "
        else          text.to_s
        end
      elsif options.key?(:template)
        template = options.delete(:template)
        
        super(template)
      end
    end
    
    private
    def _process_options(options)
      if status = options.delete(:status)
        response.status = status.to_i
      end
    end
  end
end