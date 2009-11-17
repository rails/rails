module ActionController
  module Configuration
    extend ActiveSupport::Concern
    
    def config
      @config ||= self.class.config
    end
    
    def config=(config)
      @config = config
    end
    
    module ClassMethods
      def default_config
        @default_config ||= {}
      end
      
      def config
        self.config ||= default_config
      end
      
      def config=(config)
        @config = ActiveSupport::OrderedHash.new
        @config.merge!(config)
      end
    end
  end
end