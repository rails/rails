module ActiveSupport
  module CachingTools #:nodoc:
    
    # Provide shortcuts to simply the creation of nested default hashes. This
    # pattern is useful, common practice, and unsightly when done manually.
    module HashCaching
      # Dynamically create a nested hash structure used to cache calls to +method_name+
      # The cache method is named +#{method_name}_cache+ unless :as => :alternate_name
      # is given.
      #
      # The hash structure is created using nested Hash.new. For example:
      # 
      #   def slow_method(a, b) a ** b end
      # 
      # can be cached using hash_cache :slow_method, which will define the method
      # slow_method_cache. We can then find the result of a ** b using:
      # 
      #   slow_method_cache[a][b]
      # 
      # The hash structure returned by slow_method_cache would look like this:
      # 
      #   Hash.new do |as, a|
      #     as[a] = Hash.new do |bs, b|
      #       bs[b] = slow_method(a, b)
      #     end
      #   end
      # 
      # The generated code is actually compressed onto a single line to maintain
      # sensible backtrace signatures.
      #
      def hash_cache(method_name, options = {})
        selector = options[:as] || "#{method_name}_cache"
        method = self.instance_method(method_name)
        
        args = []
        code = "def #{selector}(); @#{selector} ||= "
        
        (1..method.arity).each do |n|
          args << "v#{n}"
          code << "Hash.new {|h#{n}, v#{n}| h#{n}[v#{n}] = "
        end
        
        # Add the method call with arguments, followed by closing braces and end.
        code << "#{method_name}(#{args * ', '}) #{'}' * method.arity} end"
        
        # Extract the line number information from the caller. Exceptions arising
        # in the generated code should point to the +hash_cache :...+ line.
        if caller[0] && /^(.*):(\d+)$/ =~ caller[0]
          file, line_number = $1, $2.to_i
        else # We can't give good trackback info; fallback to this line:
          file, line_number = __FILE__, __LINE__
        end
        
        # We use eval rather than building proc's because it allows us to avoid
        # linking the Hash's to this method's binding. Experience has shown that
        # doing so can cause obtuse memory leaks.
        class_eval code, file, line_number
      end
    end
    
  end
end
