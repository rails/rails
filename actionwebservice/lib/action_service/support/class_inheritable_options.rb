class Class # :nodoc:
  def class_inheritable_option(sym, default_value=nil)
    write_inheritable_attribute sym, default_value
    class_eval <<-EOS
      def self.#{sym}(value=nil)
        if !value.nil?
          write_inheritable_attribute(:#{sym}, value)
        else
          read_inheritable_attribute(:#{sym})
        end
      end
      
      def self.#{sym}=(value)
        write_inheritable_attribute(:#{sym}, value)
      end

      def #{sym}
        self.class.#{sym}
      end

      def #{sym}=(value)
        self.class.#{sym} = value
      end
    EOS
  end
end
