module ActiveModel
  class Errors < Hash
    include DeprecatedErrorMethods
    
    @@default_error_messages = {
      :inclusion                => "is not included in the list",
      :exclusion                => "is reserved",
      :invalid                  => "is invalid",
      :confirmation             => "doesn't match confirmation",
      :accepted                 => "must be accepted",
      :empty                    => "can't be empty",
      :blank                    => "can't be blank",
      :too_long                 => "is too long (maximum is %d characters)",
      :too_short                => "is too short (minimum is %d characters)",
      :wrong_length             => "is the wrong length (should be %d characters)",
      :taken                    => "has already been taken",
      :not_a_number             => "is not a number",
      :greater_than             => "must be greater than %d",
      :greater_than_or_equal_to => "must be greater than or equal to %d",
      :equal_to                 => "must be equal to %d",
      :less_than                => "must be less than %d",
      :less_than_or_equal_to    => "must be less than or equal to %d",
      :odd                      => "must be odd",
      :even                     => "must be even"
    }
  
    # Holds a hash with all the default error messages that can be replaced by your own copy or localizations.
    cattr_accessor :default_error_messages

    alias_method :get, :[]
    alias_method :set, :[]=

    def [](attribute)
      if errors = get(attribute.to_sym)
        errors.size == 1 ? errors.first : errors
      else
        set(attribute.to_sym, [])
      end
    end

    def []=(attribute, error)
      self[attribute.to_sym] << error
    end

    def each
      each_key do |attribute| 
        self[attribute].each { |error| yield attribute, error }
      end
    end

    def size
      values.flatten.size
    end

    def to_a
      inject([]) do |errors_with_attributes, (attribute, errors)|
        if error.blank?
          errors_with_attributes
        else
          if attr == :base
            errors_with_attributes << error
          else
            errors_with_attributes << (attribute.to_s.humanize + " " + error)
          end
        end
      end
    end

    def to_xml(options={})
      options[:root]    ||= "errors"
      options[:indent]  ||= 2
      options[:builder] ||= Builder::XmlMarkup.new(:indent => options[:indent])

      options[:builder].instruct! unless options.delete(:skip_instruct)
      options[:builder].errors do |e|
        to_a.each { |error| e.error(error) }
      end
    end
  end
end