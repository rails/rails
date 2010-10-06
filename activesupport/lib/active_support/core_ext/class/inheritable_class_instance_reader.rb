class Class
  def inheritable_class_instance_reader(*attrs)
    attrs.each do |attr|
      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        def self.#{attr}
          if defined?(@#{attr})
            @#{attr}
          elsif superclass != Object && (t = superclass.#{attr})
            begin            
              t.dup.freeze
            rescue TypeError
              t
            end
          end
        end
      RUBY
    end
  end
end
