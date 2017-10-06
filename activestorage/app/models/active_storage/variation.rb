# frozen_string_literal: true

# A set of transformations that can be applied to a blob to create a variant. This class is exposed via
# the ActiveStorage::Blob#variant method and should rarely be used directly.
#
# In case you do need to use this directly, it's instantiated using a hash of transformations where
# the key is the command and the value is the arguments. Example:
#
#   ActiveStorage::Variation.new(resize: "100x100", monochrome: true, trim: true, rotate: "-90")
#
# A list of all possible transformations is available at https://www.imagemagick.org/script/mogrify.php.
class ActiveStorage::Variation
  attr_reader :transformations

  class << self
    def wrap(variation_or_key)
      case variation_or_key
      when self
        variation_or_key
      else
        decode variation_or_key
      end
    end

    # Returns a variation instance with the transformations that were encoded by +encode+.
    def decode(key)
      new ActiveStorage.verifier.verify(key, purpose: :variation)
    end

    # Returns a signed key for the +transformations+, which can be used to refer to a specific
    # variation in a URL or combined key (like <tt>ActiveStorage::Variant#key</tt>).
    def encode(transformations)
      ActiveStorage.verifier.generate(transformations, purpose: :variation)
    end
  end

  def initialize(transformations)
    @transformations = transformations
  end

  # Accepts an open MiniMagick image instance, like what's returned by <tt>MiniMagick::Image.read(io)</tt>,
  # and performs the +transformations+ against it. The transformed image instance is then returned.
  def transform(image)
    transformations.each do |(method, argument)|
      if eligible_argument?(argument)
        image.public_send(method, argument)
      else
        image.public_send(method)
      end
    end
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  private
    def eligible_argument?(argument)
      argument.present? && argument != true
    end
end
