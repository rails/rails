require "active_support/core_ext/object/inclusion"

# A set of transformations that can be applied to a blob to create a variant.
class ActiveStorage::Variation
  attr_reader :transformations

  class << self
    def decode(key)
      new ActiveStorage.verifier.verify(key)
    end

    def encode(transformations)
      ActiveStorage.verifier.generate(transformations)
    end
  end

  def initialize(transformations)
    @transformations = transformations
  end

  def transform(image)
    transformations.each do |(method, argument)|
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
    def eligible_argument?(argument)
      argument.present? && argument != true
    end
end
