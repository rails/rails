module MarshalWithAutoloading
    def load(source)
      super(source)
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

Marshal.module_eval do
  class << self
    prepend(MarshalWithAutoloading)
  end
end
