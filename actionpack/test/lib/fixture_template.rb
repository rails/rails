module ActionView #:nodoc:
  class FixtureTemplate < Template
    class FixturePath < Template::Path
      def initialize(hash = {})
        @hash = {}
        
        hash.each do |k, v|
          @hash[k.sub(/\.\w+$/, '')] = FixtureTemplate.new(v, k.split("/").last, self)
        end
        
        super("fixtures://root")
      end
      
      def find_template(path)
        @hash[path]
      end
    end
    
    def initialize(body, *args)
      @body = body
      super(*args)
    end
    
    def source
      @body
    end
  
  private
  
    def find_full_path(path, load_paths)
      return '/', path
    end
  
  end
end