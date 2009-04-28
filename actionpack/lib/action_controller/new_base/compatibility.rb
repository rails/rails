module ActionController
  module Rails2Compatibility
  
    def render_to_body(options)
      if options.is_a?(Hash) && options.key?(:template)
        options[:template].sub!(/^\//, '')
      end
      super
    end
   
  end
end