module Marshal
  class << self
    def load_with_autoloading(source)
      begin
        load_without_autoloading(source)
      rescue ArgumentError, NameError => exc
        if exc.message.match(%r|undefined class/module (.+)|)
          # try loading the class/module
          $1.constantize
          # if it is a IO we need to go back to read the object
          source.rewind if source.respond_to?(:rewind)
          retry
        else
          raise exc
        end
      end
    end

    alias_method_chain :load, :autoloading
  end
end