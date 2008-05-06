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
      class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}
          @@#{sym}
        end

        def #{sym}
          @@#{sym}
        end
      EOS
    end
  end

  def cattr_writer(*syms)
    options = syms.extract_options!
    syms.flatten.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__)
        unless defined? @@#{sym}
          @@#{sym} = nil
        end

        def self.#{sym}=(obj)
          @@#{sym} = obj
        end

        #{"
        def #{sym}=(obj)
          @@#{sym} = obj
        end
        " unless options[:instance_writer] == false }
      EOS
    end
  end

  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end
