require File.dirname(__FILE__) + '/abstract_unit'


module Foo
  include ActionWebService::Protocol

  def self.append_features(base)
    super
    base.register_protocol(BodyOnly, FooMinimalProtocol)
    base.register_protocol(HeaderAndBody, FooMinimalProtocolTwo)
    base.register_protocol(HeaderAndBody, FooMinimalProtocolTwo)
    base.register_protocol(HeaderAndBody, FooFullProtocol)
  end

  class FooFullProtocol < AbstractProtocol
    def self.create_protocol_request(klass, request)
      protocol = FooFullProtocol.new klass
      ActionWebService::Protocol::ProtocolRequest.new(protocol, '', '', '', '')
    end
  end

  class FooMinimalProtocol < AbstractProtocol
    def self.create_protocol_request(klass, request)
      protocol = FooMinimalProtocol.new klass
      ActionWebService::Protocol::ProtocolRequest.new(protocol, '', '', '', '')
    end
  end

  class FooMinimalProtocolTwo < AbstractProtocol
  end
end

class ProtocolRegistry
  include ActionWebService::Protocol::Registry
  include Foo

  def all_protocols
    header_and_body_protocols + body_only_protocols
  end

  def protocol_request
    probe_request_protocol(nil)
  end
end


class TC_ProtocolRegistry < Test::Unit::TestCase
  def test_registration
    registry = ProtocolRegistry.new
    assert(registry.all_protocols.length == 4)
    assert(registry.protocol_request.protocol.is_a?(Foo::FooFullProtocol))
  end
end
