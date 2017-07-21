require "active_support/core_ext/object/inclusion"

# A set of transformations that can be applied to a blob to create a variant.
class ActiveStorage::Variation
  class_attribute :verifier

  ALLOWED_TRANSFORMATIONS = %i(
    resize rotate format flip fill monochrome orient quality roll scale sharpen shave shear size thumbnail
    transparent transpose transverse trim background bordercolor compress crop
  )

  attr_reader :transformations

  class << self
    def decode(key)
      new verifier.verify(key)
    end
    
    def encode(transformations)
      verifier.generate(transformations)
    end
  end

  def initialize(transformations)
    @transformations = transformations
  end

  def transform(image)
    transformations.each do |(method, argument)|
      next unless eligible_transformation?(method)

      if eligible_argument?(argument)
        image.public_send(method, argument)
      else
        image.public_send(method)
      end
    end
  end

  def key
    self.class.encode(transformations)
  end

  private
    def eligible_transformation?(method)
      method.to_sym.in?(ALLOWED_TRANSFORMATIONS)
    end

    # FIXME: Consider whitelisting allowed arguments as well?
    def eligible_argument?(argument)
      argument.present? && argument != true
    end
end
