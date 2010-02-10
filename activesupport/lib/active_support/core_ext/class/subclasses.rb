require 'active_support/core_ext/object/blank'

class Class #:nodoc:
  # Returns an array with the names of the subclasses of +self+ as strings.
  #
  #   Integer.subclasses # => ["Bignum", "Fixnum"]
  def subclasses
    Class.subclasses_of(self).map { |o| o.to_s }
  end

  def reachable? #:nodoc:
    eval("defined?(::#{self}) && ::#{self}.equal?(self)")
  end

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

  # Exclude this class unless it's a subclass of our supers and is defined.
  # We check defined? in case we find a removed class that has yet to be
  # garbage collected. This also fails for anonymous classes -- please
  # submit a patch if you have a workaround.
  def self.subclasses_of(*superclasses) #:nodoc:
    subclasses = []
    superclasses.each do |klass|
      subclasses.concat klass.descendents.select {|k| k.name.blank? || k.reachable?}
    end
    subclasses
  end
end
