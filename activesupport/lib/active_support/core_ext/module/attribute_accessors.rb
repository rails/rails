require 'active_support/core_ext/array/extract_options'

class Module
  def mattr_reader(*syms)
    syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}  # unless defined? @@pagination_options
          @@#{sym} = nil          #   @@pagination_options = nil
        end                       # end

        def self.#{sym}           # def self.pagination_options
          @@#{sym}                #   @@pagination_options
        end                       # end

        def #{sym}                # def pagination_options
          @@#{sym}                #   @@pagination_options
        end                       # end
      EOS
    end
  end

  def mattr_writer(*syms)
    options = syms.extract_options!
    syms.each do |sym|
      class_eval(<<-EOS, __FILE__, __LINE__ + 1)
        unless defined? @@#{sym}                       # unless defined? @@pagination_options
          @@#{sym} = nil                               #   @@pagination_options = nil
        end                                            # end

        def self.#{sym}=(obj)                          # def self.pagination_options=(obj)
          @@#{sym} = obj                               #   @@pagination_options = obj
        end                                            # end
      EOS

      unless options[:instance_writer] == false
        class_eval(<<-EOS, __FILE__, __LINE__)
          def #{sym}=(obj)                             # def pagination_options=(obj)
            @@#{sym} = obj                             #   @@pagination_options = obj
          end                                          # end
        EOS
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
  def mattr_accessor(*syms)
    mattr_reader(*syms)
    mattr_writer(*syms)
  end
end
