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
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
      def self.#{name}                                                                            # def self.property
        if defined?(@#{name})                                                                     #   if defined?(@property)
          @#{name}                                                                                #     @property
        elsif superclass < #{class_name_to_stop_searching_on} && superclass.respond_to?(:#{name}) #   elseif superclass < Object && superclass.respond_to?(:property)
          superclass.#{name}                                                                      #     superclass.property
        end                                                                                       #   end
      end                                                                                         # end
      def #{name}                                                                                 # def property
        self.class.#{name}                                                                        #   self.class.property
      end                                                                                         # end
      def self.#{name}?                                                                           # def self.property?
        !!#{name}                                                                                 #   !!property
      end                                                                                         # end
      def #{name}?                                                                                # def property?
        !!#{name}                                                                                 #   !!property
      end                                                                                         # end
      EOS
    end
  end

  def superclass_delegating_writer(*names)
    names.each do |name|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def self.#{name}=(value)     # def self.property=(value)
          @#{name} = value           #   @property = value
        end                          # end
      EOS
    end
  end

  def superclass_delegating_accessor(*names)
    superclass_delegating_reader(*names)
    superclass_delegating_writer(*names)
  end
end
