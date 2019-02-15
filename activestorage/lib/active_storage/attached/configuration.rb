# frozen_string_literal: true

module ActiveStorage
  # Provides a configuration object use to configure the attachment
  class Attached::Configuration < Hash
    def initialize
      super
      self.merge!(defined_variants: {})
    end

    # Defines a set of transformations that can be referred to by name when
    # generating a variant
    #
    #   has_variant(:thumbnail, resize: "50x50", monochrome: true)
    #
    # A thumbnail can later be generated using
    #
    #   @user.avatar.variant(:thumbnail)
    def has_variant(name, transformations = {})
      self[:defined_variants][name.to_sym] = transformations
    end
  end
end
