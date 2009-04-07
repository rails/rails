module AbstractController
  module Helpers
    depends_on Renderer
    
    setup do
      extlib_inheritable_accessor :master_helper_module
      self.master_helper_module = Module.new
    end
  
    # def self.included(klass)
    #   klass.class_eval do
    #     extlib_inheritable_accessor :master_helper_module
    #     self.master_helper_module = Module.new
    #   end
    # end
    
    def _action_view
      @_action_view ||= begin
        av = super
        av.helpers.send(:include, master_helper_module)
        av
      end
    end
    
    module ClassMethods
      def inherited(klass)
        klass.master_helper_module = Module.new
        klass.master_helper_module.__send__ :include, master_helper_module
        
        super
      end
      
      def add_template_helper(mod)
        master_helper_module.module_eval { include mod }
      end
      
      def helper_method(*meths)
        meths.flatten.each do |meth|
          master_helper_module.class_eval <<-ruby_eval, __FILE__, __LINE__ + 1
            def #{meth}(*args, &blk)
              controller.send(%(#{meth}), *args, &blk)
            end
          ruby_eval
        end
      end
      
      def helper(*args, &blk)
        args.flatten.each do |arg|
          case arg
          when Module
            add_template_helper(arg)
          end
        end
        master_helper_module.module_eval(&blk) if block_given?
      end
    end
    
  end
end