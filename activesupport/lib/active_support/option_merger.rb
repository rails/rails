module ActiveSupport
  class OptionMerger #:nodoc:
    instance_methods.each do |method| 
      undef_method(method) if method !~ /^(__|instance_eval)/
    end
    
    def initialize(context, options)
      @context, @options = context, options
    end
    
    private
      def method_missing(method, *arguments, &block)
        merge_argument_options! arguments
        @context.send(method, *arguments, &block)
      end
      
      def merge_argument_options!(arguments)
        arguments << if arguments.last.respond_to? :merge!
          arguments.pop.dup.merge!(@options)
        else
          @options.dup
        end  
      end
  end
end
