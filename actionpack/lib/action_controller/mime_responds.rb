module ActionController #:nodoc:
  module MimeResponds #:nodoc:
    def self.included(base)
      base.send(:include, ActionController::MimeResponds::InstanceMethods)
    end

    module InstanceMethods
      def respond_to(&block)
        responder = Responder.new(block.binding)
        yield responder
        responder.respond
      end
    end
    
    class Responder #:nodoc:
      DEFAULT_BLOCKS = {
        :html    => 'Proc.new { render }',
        :js      => 'Proc.new { render :action => "#{action_name}.rjs" }',
        :xml     => 'Proc.new { render :action => "#{action_name}.rxml" }',
        :xml_arg => 'Proc.new { render :xml => __mime_responder_arg__ }'
      }
      
      def initialize(block_binding)
        @block_binding = block_binding
        @mime_type_priority = eval("request.accepts", block_binding)
        @order     = []
        @responses = {}
      end

      def custom(mime_type, *args, &block)
        mime_type = mime_type.is_a?(Mime::Type) ? mime_type : Mime::Type.lookup(mime_type.to_s)
        
        @order << mime_type
        
        if block_given?
          @responses[mime_type] = block
        else
          if argument = args.first
            eval("__mime_responder_arg__ = #{argument.is_a?(String) ? argument.inspect : argument}", @block_binding)
            @responses[mime_type] = eval(DEFAULT_BLOCKS[(mime_type.to_sym.to_s + "_arg").to_sym], @block_binding)
          else
            @responses[mime_type] = eval(DEFAULT_BLOCKS[mime_type.to_sym], @block_binding)
          end
        end
      end
      
      for mime_type in %w( all html js xml rss atom yaml )
        eval <<-EOT
          def #{mime_type}(argument = nil, &block)
            custom(Mime::#{mime_type.upcase}, argument, &block)
          end
        EOT
      end

      def any(*args, &block)
        args.each { |type| send(type, &block) }
      end
      
      def respond
        for priority in @mime_type_priority
          if priority == Mime::ALL
            @responses[@order.first].call
            return
          else
            if priority === @order
              @responses[priority].call
              return # mime type match found, be happy and return
            end
          end
        end
        
        if @order.include?(Mime::ALL)
          @responses[Mime::ALL].call
        else
          eval 'render(:nothing => true, :status => "406 Not Acceptable")', @block_binding
        end
      end
    end
  end
end