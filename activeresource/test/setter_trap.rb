class SetterTrap < BasicObject
  class << self
    def rollback_sets(obj)
      returning yield(setter_trap = new(obj)) do
        setter_trap.rollback_sets
      end
    end
  end

  def initialize(obj)
    @cache = {}
    @obj = obj
  end

  def respond_to?(method)
    @obj.respond_to?(method)
  end

  def method_missing(method, *args, &proc)
    @cache[method] ||= @obj.send($`) if method.to_s =~ /=$/
    @obj.send method, *args, &proc
  end

  def rollback_sets
    @cache.each { |k, v| @obj.send k, v }
  end
end
