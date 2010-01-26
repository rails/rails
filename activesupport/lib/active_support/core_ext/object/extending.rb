require 'active_support/core_ext/class/removal'
require 'active_support/core_ext/object/blank'

class Class
  # Rubinius
  if defined?(Class.__subclasses__)
    def descendents
      subclasses = []
      __subclasses__.each {|k| subclasses << k; subclasses.concat k.descendents }
      subclasses
    end
  else
    # MRI
    begin
      ObjectSpace.each_object(Class.new) {}

      def descendents
        subclasses = []
        ObjectSpace.each_object(class << self; self; end) do |k|
          subclasses << k unless k == self
        end
        subclasses
      end
    # JRuby
    rescue StandardError
      def descendents
        subclasses = []
        ObjectSpace.each_object(Class) do |k|
          subclasses << k if k < self
        end
        subclasses.uniq!
        subclasses
      end
    end
  end
end

class Object
  def extended_by #:nodoc:
    ancestors = class << self; ancestors end
    ancestors.select { |mod| mod.class == Module } - [ Object, Kernel ]
  end

  def extend_with_included_modules_from(object) #:nodoc:
    object.extended_by.each { |mod| extend mod }
  end
end
