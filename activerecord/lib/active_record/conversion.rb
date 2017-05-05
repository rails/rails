module ActiveRecord
  module Conversion # :nodoc:
    include ActiveModel::Conversion

    # Wrapper around <tt>ActiveModel::Conversion#to_model</tt> to return an
    # instance of the <tt>ActiveRecord::Errors</tt> class for the model's
    # errors.
    def to_model
      @errors = Errors.new(self)
      # fill validation errors
      validate

      super.dup
    end
  end
end
