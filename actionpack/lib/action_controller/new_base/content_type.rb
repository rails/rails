module ActionController
  module ContentType
    
    def render_to_body(options = {})
      if content_type = options[:content_type]
        response.content_type = content_type
      end
      
      ret = super
      response.content_type ||= options[:_template].mime_type
      ret
    end

  end
end