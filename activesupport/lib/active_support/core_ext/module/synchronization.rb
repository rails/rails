require 'active_support/core_ext/module/aliasing'
require 'active_support/core_ext/array/extract_options'

class Module
  # Synchronize access around a method, delegating synchronization to a
  # particular mutex. A mutex (either a Mutex, or any object that responds to 
  # #synchronize and yields to a block) must be provided as a final :with option.
  # The :with option should be a symbol or string, and can represent a method, 
  # constant, or instance or class variable.
  # Example:
  #   class SharedCache
  #     @@lock = Mutex.new
  #     def expire
  #       ...
  #     end
  #     synchronize :expire, :with => :@@lock
  #   end
  def synchronize(*methods)
    options = methods.extract_options!
    unless options.is_a?(Hash) && with = options[:with]
      raise ArgumentError, "Synchronization needs a mutex. Supply an options hash with a :with key as the last argument (e.g. synchronize :hello, :with => :@mutex)."
    end

    methods.each do |method|
      aliased_method, punctuation = method.to_s.sub(/([?!=])$/, ''), $1

      if method_defined?("#{aliased_method}_without_synchronization#{punctuation}")
        raise ArgumentError, "#{method} is already synchronized. Double synchronization is not currently supported."
      end

      module_eval(<<-EOS, __FILE__, __LINE__ + 1)
        def #{aliased_method}_with_synchronization#{punctuation}(*args, &block)     # def expire_with_synchronization(*args, &block)
          #{with}.synchronize do                                                    #   @@lock.synchronize do
            #{aliased_method}_without_synchronization#{punctuation}(*args, &block)  #     expire_without_synchronization(*args, &block)
          end                                                                       #   end
        end                                                                         # end
      EOS

      alias_method_chain method, :synchronization
    end
  end
end
