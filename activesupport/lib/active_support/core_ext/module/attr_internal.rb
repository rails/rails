class Module
  # Declares an attribute reader backed by an internally-named instance variable.
  def attr_internal_reader(*attrs)
    attrs.each do |attr|
      module_eval "def #{attr}() #{attr_internal_ivar_name(attr)} end"
    end
  end

  # Declares an attribute writer backed by an internally-named instance variable.
  def attr_internal_writer(*attrs)
    attrs.each do |attr|
      module_eval "def #{attr}=(v) #{attr_internal_ivar_name(attr)} = v end"
    end
  end

  # Declares an attribute reader and writer backed by an internally-named instance
  # variable.
  def attr_internal_accessor(*attrs)
    attr_internal_reader(*attrs)
    attr_internal_writer(*attrs)
  end

  alias_method :attr_internal, :attr_internal_accessor

  private
    mattr_accessor :attr_internal_naming_format
    self.attr_internal_naming_format = '@_%s'

    def attr_internal_ivar_name(attr)
      attr_internal_naming_format % attr
    end
end
