module ActionController
  module Http
    class Headers < ::Hash
      
      def initialize(constructor = {})
         if constructor.is_a?(Hash)
           super()
           update(constructor)
         else
           super(constructor)
         end
       end
      
      def [](header_name)
        if include?(header_name)
          super 
        else
          super(normalize_header(header_name))
        end
      end
      
      
      private
        # Takes an HTTP header name and returns it in the 
        # format 
        def normalize_header(header_name)
          "HTTP_#{header_name.upcase.gsub(/-/, '_')}"
        end
    end
  end
end