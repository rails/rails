# Extends the class object with class and instance accessors for class attributes, 
# just like the native attr* accessors for instance attributes.
class Class # :nodoc:
  def cattr_reader(*syms)
    syms.each do |sym|
      class_eval <<-EOS
        if ! defined? @@#{sym.id2name}
          @@#{sym.id2name} = nil
        end
        
        def self.#{sym.id2name}
          @@#{sym}
        end

        def #{sym.id2name}
          @@#{sym}
        end

        def call_#{sym.id2name}
          case @@#{sym.id2name}
            when Symbol then send(@@#{sym})
            when Proc   then @@#{sym}.call(self)
            when String then @@#{sym}
            else nil
          end
        end
      EOS
    end
  end
  
  def cattr_writer(*syms)
    syms.each do |sym|
      class_eval <<-EOS
        if ! defined? @@#{sym.id2name}
          @@#{sym.id2name} = nil
        end
        
        def self.#{sym.id2name}=(obj)
          @@#{sym.id2name} = obj
        end

        def self.set_#{sym.id2name}(obj)
          @@#{sym.id2name} = obj
        end

        def #{sym.id2name}=(obj)
          @@#{sym} = obj
        end
      EOS
    end
  end
  
  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end
end