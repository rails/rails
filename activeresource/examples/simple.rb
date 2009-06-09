$LOAD_PATH.unshift "#{File.dirname(__FILE__)}/../lib"
require 'active_resource'
require 'active_support/core_ext/hash/conversions'

ActiveSupport::XmlMini.backend = ENV['XMLMINI'] || 'REXML'
ActiveResource::HttpMock.respond_to do |mock|
  mock.get '/people/1.xml', {}, { :id => 1, :name => 'bob' }.to_xml(:root => 'person')
end

class Person < ActiveResource::Base
  self.site = 'http://localhost/'
end

bob = Person.find(1)
puts bob.inspect
