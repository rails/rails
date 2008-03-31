# These class attributes behave something like the class
# inheritable accessors.  But instead of copying the hash over at
# the time the subclass is first defined,  the accessors simply
# delegate to their superclass unless they have been given a 
# specific value.  This stops the strange situation where values 
# set after class definition don't get applied to subclasses.
class Class
  def superclass_delegating_reader(*names)
    class_name_to_stop_searching_on = self.superclass.name.blank? ? "Object" : self.superclass.name
    names.each do |name|
      class_eval <<-EOS
      def self.#{name}
        if defined?(@#{name})
          @#{name}
        elsif superclass < #{class_name_to_stop_searching_on} && superclass.respond_to?(:#{name})
          superclass.#{name}
        end
      end
      def #{name}
        self.class.#{name}
      end
      def self.#{name}?
        !!#{name}
      end
      def #{name}?
        !!#{name}
      end
      EOS
    end
  end

  def superclass_delegating_writer(*names)
    names.each do |name|
      class_eval <<-EOS
        def self.#{name}=(value)
          @#{name} = value
        end
      EOS
    end
  end

  def superclass_delegating_accessor(*names)
    superclass_delegating_reader(*names)
    superclass_delegating_writer(*names)
  end
end
