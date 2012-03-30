require 'active_support/core_ext/array/extract_options'

class Module
  def mattr_reader(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_variable_set(:"@@#{sym}", nil) unless class_variable_defined?(:"@@#{sym}")

      define_singleton_method(sym) do
        class_variable_get(:"@@#{sym}")
      end

      unless options[:instance_reader] == false || options[:instance_accessor] == false
        define_method(sym) do
          self.class.class_variable_get(:"@@#{sym}")
        end
      end
    end
  end

  def mattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      define_singleton_method("#{sym}=") do |obj|
        class_variable_set(:"@@#{sym}", obj)
      end

      unless options[:instance_writer] == false || options[:instance_accessor] == false
        define_method("#{sym}=") do |obj|
          self.class.class_variable_set(:"@@#{sym}", obj)
        end
      end
    end
  end

  # Extends the module object with module and instance accessors for class attributes,
  # just like the native attr* accessors for instance attributes.
  #
  #  module AppConfiguration
  #    mattr_accessor :google_api_key
  #    self.google_api_key = "123456789"
  #
  #    mattr_accessor :paypal_url
  #    self.paypal_url = "www.sandbox.paypal.com"
  #  end
  #
  #  AppConfiguration.google_api_key = "overriding the api key!"
  #
  # To opt out of the instance writer method, pass :instance_writer => false.
  # To opt out of the instance reader method, pass :instance_reader => false.
  # To opt out of both instance methods, pass :instance_accessor => false.
  def mattr_accessor(*syms)
    mattr_reader(*syms)
    mattr_writer(*syms)
  end
end
