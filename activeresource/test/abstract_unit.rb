require 'test/unit'

$:.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_resource'
require 'active_resource/http_mock'
require 'active_support/breakpoint'

ActiveResource::Base.logger = Logger.new("#{File.dirname(__FILE__)}/debug.log")

class SetterTrap < Builder::BlankSlate
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
    @cache[method] = @obj.send(method.to_s[0 ... -1]) if method.to_s[-1 .. -1] == "=" unless @cache[method]
    @obj.send method, *args, &proc
  end
  
  def rollback_sets
    @cache.each { |k, v| @obj.send k, v }
  end
end