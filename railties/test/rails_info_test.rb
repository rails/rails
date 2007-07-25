$:.unshift File.dirname(__FILE__) + "/../lib"
$:.unshift File.dirname(__FILE__) + "/../builtin/rails_info"
$:.unshift File.dirname(__FILE__) + "/../../activesupport/lib"

require 'test/unit'
require 'active_support'

unless defined?(Rails) && defined?(Rails::Info)
  module Rails
    class Info; end
  end
end

class InfoTest < Test::Unit::TestCase
  def setup
    Rails.send :remove_const, :Info
    silence_warnings { load 'rails/info.rb' }
  end

  def test_edge_rails_revision_not_set_when_svn_info_is_empty
    Rails::Info.property 'Test that this will not be defined' do
      Rails::Info.edge_rails_revision ''
    end
    assert !property_defined?('Test that this will not be defined')
  end
  
  def test_edge_rails_revision_extracted_from_svn_info
    Rails::Info.property 'Test Edge Rails revision' do
      Rails::Info.edge_rails_revision <<-EOS
Path: .
URL: http://www.rubyonrails.com/svn/rails/trunk
Repository UUID: 5ecf4fe2-1ee6-0310-87b1-e25e094e27de
Revision: 2881
Node Kind: directory
Schedule: normal
Last Changed Author: sam
Last Changed Rev: 2881
Last Changed Date: 2005-11-04 21:04:41 -0600 (Fri, 04 Nov 2005)
Properties Last Updated: 2005-10-28 19:30:00 -0500 (Fri, 28 Oct 2005)

EOS
    end
  
    assert_property 'Test Edge Rails revision', '2881'
  end
  
  def test_property_with_block_swallows_exceptions_and_ignores_property
    assert_nothing_raised do
      Rails::Info.module_eval do
        property('Bogus') {raise}
      end
    end
    assert !property_defined?('Bogus')
  end
  
  def test_property_with_string
    Rails::Info.module_eval do
      property 'Hello', 'World'
    end
    assert_property 'Hello', 'World'
  end
  
  def test_property_with_block
    Rails::Info.module_eval do
      property('Goodbye') {'World'}
    end
    assert_property 'Goodbye', 'World'
  end
  
  def test_component_version
    assert_property 'Active Support version', ActiveSupport::VERSION::STRING
  end
  
  def test_components_exist
    Rails::Info.components.each do |component|
      dir = File.dirname(__FILE__) + "/../../" + component.gsub('_', '')
      assert File.directory?(dir), "#{component.classify} does not exist"
    end
  end

protected
  def svn_info=(info)
    Rails::Info.module_eval do
      class << self
        def svn_info
          info
        end
      end
    end
  end
  
  def properties
    Rails::Info.properties
  end

  def property_defined?(property_name)
    properties.names.include? property_name
  end
  
  def assert_property(property_name, value)
    raise "Property #{property_name.inspect} not defined" unless 
      property_defined? property_name
    assert_equal value, properties.value_for(property_name)
  end
end
