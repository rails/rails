require 'active_support/core_ext/array/extract_options'

class Module
  def mattr_reader(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new('invalid attribute name') unless sym =~ /^[_A-Za-z]\w*$/
      cvar = "@@#{sym}"
      module_exec do
        class_variable_set(cvar, nil) unless class_variable_defined?(cvar)

        define_singleton_method(sym) do
          class_variable_get(cvar)
        end
      end

      unless options[:instance_reader] == false || options[:instance_accessor] == false
        module_exec do
          define_method(sym) do
            self.class.class_variable_get(cvar)
          end
        end
      end
    end
  end

  def mattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      raise NameError.new('invalid attribute name') unless sym =~ /^[_A-Za-z]\w*$/
      cvar = "@@#{sym}"
      module_exec do
        define_singleton_method("#{sym}=") do |obj|
          class_variable_set(cvar, obj)
        end
      end

      unless options[:instance_writer] == false || options[:instance_accessor] == false
        module_exec do
          define_method("#{sym}=") do |obj|
            self.class.class_variable_set(cvar, obj)
          end
        end
      end
    end
  end

  # Extends the module object with module and instance accessors for class attributes,
  # just like the native attr* accessors for instance attributes.
  #
  #   module AppConfiguration
  #     mattr_accessor :google_api_key
  #
  #     self.google_api_key = "123456789"
  #   end
  #
  #   AppConfiguration.google_api_key # => "123456789"
  #   AppConfiguration.google_api_key = "overriding the api key!"
  #   AppConfiguration.google_api_key # => "overriding the api key!"
  #
  # To opt out of the instance writer method, pass <tt>instance_writer: false</tt>.
  # To opt out of the instance reader method, pass <tt>instance_reader: false</tt>.
  # To opt out of both instance methods, pass <tt>instance_accessor: false</tt>.
  def mattr_accessor(*syms)
    mattr_reader(*syms)
    mattr_writer(*syms)
  end
end
