module ActionController
  module Rails2Compatibility
  
    def render_to_body(options)
      if options.is_a?(Hash) && options.key?(:template)
        options[:template].sub!(/^\//, '')
      end
      super
    end
   
   def _layout_for_name(name)
     name &&= name.sub(%r{^/?layouts/}, '')
     super
   end
   
  end
end