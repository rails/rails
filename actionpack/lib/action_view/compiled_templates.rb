module ActionView

  # CompiledTemplates modules hold methods that have been compiled.
  # Templates are compiled into these methods so that they do not need to be
  # read and parsed for each request.
  #
  # Each template may be compiled into one or more methods. Each method accepts a given
  # set of parameters which is used to implement local assigns passing.
  #
  # To use a compiled template module, create a new instance and include it into the class
  # in which you want the template to be rendered.
  class CompiledTemplates < Module
    attr_reader :method_names

    def initialize
      @method_names = Hash.new do |hash, key|
        hash[key] = "__compiled_method_#{(hash.length + 1)}"
      end
      @mtimes = {}
    end
    
    # Return the full key for the given identifier and argument names
    def full_key(identifier, arg_names)
      [identifier, arg_names]
    end

    # Return the selector for this method or nil if it has not been compiled
    def selector(identifier, arg_names)
      key = full_key(identifier, arg_names)
      method_names.key?(key) ? method_names[key] : nil
    end
    alias :compiled? :selector

    # Return the time at which the method for the given identifier and argument names was compiled.
    def mtime(identifier, arg_names)
      @mtimes[full_key(identifier, arg_names)]
    end
    
    # Compile the provided source code for the given argument names and with the given initial line number.
    # The identifier should be unique to this source.
    #
    # The file_name, if provided will appear in backtraces. If not provided, the file_name defaults
    # to the identifier.
    #
    # This method will return the selector for the compiled version of this method.
    def compile_source(identifier, arg_names, source, initial_line_number = 0, file_name = nil)
      file_name ||= identifier
      name = method_names[full_key(identifier, arg_names)]
      arg_desc = arg_names.empty? ? '' : "(#{arg_names * ', '})"
      fake_file_name = "#{file_name}#{arg_desc}" # Include the arguments for this version (for now)
      
      method_def = wrap_source(name, arg_names, source)
      
      begin
        module_eval(method_def, fake_file_name, initial_line_number)
        @mtimes[full_key(identifier, arg_names)] = Time.now
      rescue Exception => e  # errors from compiled source
        e.blame_file! identifier
        raise
      end
      name
    end
    
    # Wrap the provided source in a def ... end block.
    def wrap_source(name, arg_names, source)
      "def #{name}(#{arg_names * ', '})\n#{source}\nend"
    end
  end
end
