# attr_* style accessors for class-variables that can accessed both on an instance and class level.
class Class #:nodoc:
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
          self.class.#{sym.id2name}
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

        def #{sym.id2name}=(obj)
          self.class.#{sym.id2name}=(obj)
        end
      EOS
    end
  end
  
  def cattr_accessor(*syms)
    cattr_reader(*syms)
    cattr_writer(*syms)
  end  
end