module ActionController
  module Renderer
    
    # def self.included(klass)
    #   klass.extend ClassMethods
    # end
    # 
    # module ClassMethods
    #   def prefix
    #     @prefix ||= name.underscore
    #   end      
    # end
    
    def initialize(*)
      self.formats = [:html]
      super
    end
    
    def render(action, options = {})
      # TODO: Move this into #render_to_string
      if action.is_a?(Hash)
        options, action = action, nil 
      else
        options.merge! :action => action
      end
      
      _process_options(options)
      
      self.response_body = render_to_string(options)
    end

    def render_to_string(options)
      unless options.is_a?(Hash)
        options = {:action => options}
      end

      if options.key?(:text)
        _render_text(options)
      elsif options.key?(:template)
        template = options.delete(:template)        
        super(template)
      elsif options.key?(:action)
        template = options.delete(:action).to_s
        options[:_prefix] = _prefix 
        super(template, options)
      end
    end
    
  private
  
    def _prefix
      controller_path
    end  
  
    def _render_text(options)
      text = options.delete(:text)

      case text
      when nil then " "
      else          text.to_s
      end
    end
  
    def _process_options(options)
      if status = options.delete(:status)
        response.status = status.to_i
      end
    end
  end
end