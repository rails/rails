require 'active_support/core_ext/class/attribute_accessors'
require 'active_support/core_ext/logger'

module AbstractController
  module Logger
    extend ActiveSupport::DependencyModule

    class DelayedLog
      def initialize(&blk)
        @blk = blk
      end
      
      def to_s
        @blk.call
      end
      alias to_str to_s
    end

    included do
      cattr_accessor :logger
    end
    
    def process(action)
      ret = super
      
      if logger
        log = DelayedLog.new do
          "\n\nProcessing #{self.class.name}\##{action_name} " \
          "to #{request.formats} " \
          "(for #{request_origin}) [#{request.method.to_s.upcase}]"
        end

        logger.info(log)
      end
      
      ret
    end
    
    def request_origin
      # this *needs* to be cached!
      # otherwise you'd get different results if calling it more than once
      @request_origin ||= "#{request.remote_ip} at #{Time.now.to_s(:db)}"
    end    
  end
end
