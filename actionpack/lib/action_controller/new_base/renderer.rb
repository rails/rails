module ActionController
  module Renderer
    
    def render(options)
      if text = options[:text]
        self.response_body = text
      end
    end
    
  end
end