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
      
      for mime_type in %w( all html js xml rss atom yaml )
        eval <<-EOT
          def #{mime_type}(argument = nil, &block)
            @order << Mime::#{mime_type.upcase}
            
            if block_given?
              @responses[Mime::#{mime_type.upcase}] = block
            else
              if argument
                eval("__mime_responder_arg__ = " + (argument.is_a?(String) ? "'" + argument + "'" : argument), @block_binding)
                @responses[Mime::#{mime_type.upcase}] = eval(DEFAULT_BLOCKS[(Mime::#{mime_type.upcase}.to_sym.to_s + "_arg").to_sym], @block_binding)
              else
                @responses[Mime::#{mime_type.upcase}] = eval(DEFAULT_BLOCKS[Mime::#{mime_type.upcase}.to_sym], @block_binding)
              end
            end
          end
        EOT
      end
      
      def respond
        for priority in @mime_type_priority
          if priority == Mime::ALL
            @responses[@order.first].call
            return
          else
            if @order.include?(priority)
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