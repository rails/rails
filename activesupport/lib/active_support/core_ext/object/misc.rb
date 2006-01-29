class Object #:nodoc:
  def with_options(options)
    yield ActiveSupport::OptionMerger.new(self, options)
  end
  
  def to_json
    ActiveSupport::JSON.encode(self)
  end

  def suppress(*exception_classes)
    begin yield
    rescue Exception => e
      raise unless exception_classes.any? { |cls| e.kind_of?(cls) }
    end
  end
end