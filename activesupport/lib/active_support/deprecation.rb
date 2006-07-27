module ActiveSupport
  module Deprecation
    @@warning_method = :print
    mattr_accessor :warning_method
    
    class << self

      def print_warning(lines)
        lines.each {|l| $stderr.write("#{l}\n")}
      end
      
      def log_warning(lines)
        if Object.const_defined?("RAILS_DEFAULT_LOGGER")
          lines.each {|l| RAILS_DEFAULT_LOGGER.warn l}
        else
          print_warning(lines)
        end
      end
      
      def issue_warning(line)
        lines = 
        ["@@@@@@@@@@ Deprecation Warning @@@@@@@@@@", line,
         "@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@"]
        self.send("#{@@warning_method}_warning", lines)
      end
      
      def instance_method_warning(clazz, method)
        issue_warning("Your application calls #{clazz}##{method}, which is now deprecated.  Please see the API documents at http://api.rubyonrails.org/ for more information.")
      end
    end
    
    module ClassMethods
      def deprecate(method_name)
        alias_method "#{method_name}_before_deprecation", method_name
        class_eval(<<-EOS, __FILE__, __LINE__)
        def #{method_name}(*args)
          ::ActiveSupport::Deprecation.instance_method_warning(self.class, :#{method_name})
          #{method_name}_before_deprecation *args
        end
        EOS
      end
    end
  end
end

Object.extend(ActiveSupport::Deprecation::ClassMethods)
