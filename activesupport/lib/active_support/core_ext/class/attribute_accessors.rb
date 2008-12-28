# Extends the class object with class and instance accessors for class attributes,
# just like the native attr* accessors for instance attributes.
#
#  class Person
#    cattr_accessor :hair_colors
#  end
#
#  Person.hair_colors = [:brown, :black, :blonde, :red]
class Class
  def cattr_reader(*syms)
    syms.flatten.each do |sym|
      next if sym.is_a?(Hash)
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}   # unless defined @@property
          @@#{sym} = nil           #   @@property = nil
        end                        # end

        def self.#{sym}            # def self.property
          @@#{sym}                 #   @@property
        end                        # end

        def #{sym}                 # def property
          @@#{sym}                 #   @@property
        end                        # end
      EOS
    end
  end

  def cattr_writer(*syms)
    options = syms.extract_options!
    syms.flatten.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}   # unless defined? @@property
          @@#{sym} = nil           #   @@property = nil
        end                        # end
                                   
        def self.#{sym}=(obj)      # def self.property=(obj)
          @@#{sym} = obj           #   @@property
        end                        # end
                                   
        #{"                        
        def #{sym}=(obj)           # def property=(obj)
          @@#{sym} = obj           #   @@property = obj
        end                        # end
        " unless options[:instance_writer] == false }
      EOS
    end
  end

  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end
