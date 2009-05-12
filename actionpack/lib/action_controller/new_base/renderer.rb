module ActionController
  module Renderer
    extend ActiveSupport::DependencyModule

    depends_on AbstractController::Renderer
    
    def initialize(*)
      self.formats = [:html]
      super
    end
    
    def render_to_body(options)
      _process_options(options)
      
      if options.key?(:text)
        options[:_template] = ActionView::TextTemplate.new(_text(options))
        template = nil
      elsif options.key?(:inline)
        handler = ActionView::Template.handler_class_for_extension(options[:type] || "erb")
        template = ActionView::Template.new(options[:inline], "inline #{options[:inline].inspect}", handler, {})
        options[:_template] = template
      elsif options.key?(:template)
        options[:_template_name] = options[:template]
      elsif options.key?(:file)
        options[:_template_name] = options[:file]
      elsif options.key?(:partial)
        _render_partial(options[:partial], options)
      else
        options[:_template_name] = (options[:action] || action_name).to_s
        options[:_prefix] = _prefix 
      end
      
      ret = super(options)
      
      options[:_template] ||= _action_view._partial
      response.content_type ||= options[:_template].mime_type
      ret
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
    
    def _render_partial(partial, options)
      case partial
      when true
        options[:_prefix] = _prefix
      when String
        options[:_prefix] = _prefix unless partial.index('/')
        options[:_template_name] = partial
      else
        options[:_partial_object] = true
        return
      end
      
      options[:_partial] = options[:object] || true
    end
  
    def _process_options(options)
      status, content_type = options.values_at(:status, :content_type)
      response.status = status.to_i if status
      response.content_type = content_type if content_type
    end
  end
end
