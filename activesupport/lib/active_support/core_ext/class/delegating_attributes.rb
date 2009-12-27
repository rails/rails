require 'active_support/core_ext/object/blank'
require 'active_support/core_ext/array/extract_options'

class Class
  def superclass_delegating_reader(*names)
    class_to_stop_searching_on = superclass.name.blank? ? "Object" : superclass.name
    options = names.extract_options!

    names.each do |name|
      # def self.only_reader
      #   if defined?(@only_reader)
      #     @only_reader
      #   elsif superclass < Object && superclass.respond_to?(:only_reader)
      #     superclass.only_reader
      #   end
      # end
      class_eval <<-EOS, __FILE__, __LINE__ + 1
        def self.#{name}
          if defined?(@#{name})
            @#{name}
          elsif superclass < #{class_to_stop_searching_on} && superclass.respond_to?(:#{name})
            superclass.#{name}
          end
        end
      EOS

      unless options[:instance_reader] == false
        class_eval <<-EOS, __FILE__, __LINE__ + 1
          def #{name}                                  # def only_reader
            self.class.#{name}                         #   self.class.only_reader
          end                                          # end
          def self.#{name}?                            # def self.only_reader?
            !!#{name}                                  #   !!only_reader
          end                                          # end
          def #{name}?                                 # def only_reader?
            !!#{name}                                  #   !!only_reader
          end                                          # end
        EOS
      end
    end
  end

  def superclass_delegating_writer(*names, &block)
    options = names.extract_options!

    names.each do |name|
      class_eval <<-EOS, __FILE__, __LINE__ + 1
        def self.#{name}=(value)     # def self.property=(value)
          @#{name} = value           #   @property = value
        end                          # end
      EOS

      self.send(:"#{name}=", yield) if block_given?
    end
  end

  # These class attributes behave something like the class
  # inheritable accessors.  But instead of copying the hash over at
  # the time the subclass is first defined, the accessors simply
  # delegate to their superclass unless they have been given a 
  # specific value.  This stops the strange situation where values 
  # set after class definition don't get applied to subclasses.
  def superclass_delegating_accessor(*names, &block)
    superclass_delegating_reader(*names)
    superclass_delegating_writer(*names, &block)
  end
end
