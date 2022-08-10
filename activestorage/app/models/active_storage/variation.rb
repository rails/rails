# frozen_string_literal: true

require "mini_mime"

# A set of transformations that can be applied to a blob to create a variant. This class is exposed via
# the ActiveStorage::Blob#variant method and should rarely be used directly.
#
# In case you do need to use this directly, it's instantiated using a hash of transformations where
# the key is the command and the value is the arguments. Example:
#
#   ActiveStorage::Variation.new(resize_to_limit: [100, 100], colourspace: "b-w", rotate: "-90", saver: { trim: true })
#
# The options map directly to {ImageProcessing}[https://github.com/janko/image_processing] commands.
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

  def default_to(defaults)
    self.class.new transformations.reverse_merge(defaults)
  end

  # Accepts a File object, performs the +transformations+ against it, and
  # saves the transformed image into a temporary file.
  def transform(file, &block)
    ActiveSupport::Notifications.instrument("transform.active_storage") do
      transformer.transform(file, format: format, &block)
    end
  end

  def format
    transformations.fetch(:format, :png).tap do |format|
      if MiniMime.lookup_by_extension(format.to_s).nil?
        raise ArgumentError, "Invalid variant format (#{format.inspect})"
      end
    end
  end

  def content_type
    MiniMime.lookup_by_extension(format.to_s).content_type
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  def digest
    OpenSSL::Digest::SHA1.base64digest Marshal.dump(transformations)
  end

  private
    def transformer
      ActiveStorage::Transformers::ImageProcessingTransformer.new(transformations.except(:format))
    end
end
