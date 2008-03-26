class Module
  # Returns String#underscore applied to the module name minus trailing classes.
  #
  #   ActiveRecord.as_load_path               # => "active_record"
  #   ActiveRecord::Associations.as_load_path # => "active_record/associations"
  #   ActiveRecord::Base.as_load_path         # => "active_record" (Base is a class)
  #
  # The Kernel module gives an empty string by definition.
  #
  #   Kernel.as_load_path # => ""
  #   Math.as_load_path   # => "math"
  def as_load_path
    if self == Object || self == Kernel
      ''
    elsif is_a? Class
      parent == self ? '' : parent.as_load_path
    else
      name.split('::').collect do |word|
        word.underscore
      end * '/'
    end
  end
end