# frozen_string_literal: true

# A set of transformations that can be applied to a blob to create a variant. This class is exposed via
# the ActiveStorage::Blob#variant method and should rarely be used directly.
#
# In case you do need to use this directly, it's instantiated using a hash of transformations where
# the key is the command and the value is the arguments. Example:
#
#   ActiveStorage::Variation.new(resize_to_limit: [100, 100], monochrome: true, trim: true, rotate: "-90")
#
# The options map directly to {ImageProcessing}[https://github.com/janko-m/image_processing] commands.
class ActiveStorage::Variation
  attr_reader :transformations

  class << self
    # Returns a Variation instance based on the given variator. If the variator is a Variation, it is
    # returned unmodified. If it is a String, it is passed to ActiveStorage::Variation.decode. Otherwise,
    # it is assumed to be a transformations Hash and is passed directly to the constructor.
    def wrap(variator)
      case variator
      when self
        variator
      when String
        decode variator
      else
        new variator
      end
    end

    # Returns a Variation instance with the transformations that were encoded by +encode+.
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
    @transformations = transformations.deep_symbolize_keys
  end

  # Accepts a File object, performs the +transformations+ against it, and
  # saves the transformed image into a temporary file. If +format+ is specified
  # it will be the format of the result image, otherwise the result image
  # retains the source format.
  def transform(file, format: nil, &block)
    ActiveSupport::Notifications.instrument('transform.active_storage') do
      transformer.transform(file, format: format, &block)
    end
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  def digest
    Digest::SHA1.base64digest Marshal.dump(transformations)
  end

  private
    def transformer
      if ActiveStorage.variant_processor
        begin
          require 'image_processing'
        rescue LoadError
          ActiveSupport::Deprecation.warn <<~WARNING.squish
            Generating image variants will require the image_processing gem in Rails 6.1.
            Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.
          WARNING

          ActiveStorage::Transformers::MiniMagickTransformer.new(transformations)
        else
          ActiveStorage::Transformers::ImageProcessingTransformer.new(transformations)
        end
      else
        ActiveStorage::Transformers::MiniMagickTransformer.new(transformations)
      end
    end
end
