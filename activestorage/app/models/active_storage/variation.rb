# frozen_string_literal: true

require "marcel"

# = Active Storage \Variation
#
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

  # Accepts a File object and yields a transformed version of it. If the
  # requested variation is an identity transformation for the supplied
  # +content_type+, the original +file+ is yielded unchanged. Otherwise, the
  # transformations are applied and the result is yielded as a temporary file.
  #
  # Callers should not assume that the yielded file is always a new temporary
  # file, and should only clean it up if they own it.
  def transform(file, content_type: nil, &block)
    if content_type && identity_for?(content_type)
      file.rewind if file.respond_to?(:rewind)
      yield file
    else
      ActiveSupport::Notifications.instrument("transform.active_storage") do
        transformer.transform(file, format: format, &block)
      end
    end
  end

  def format
    transformations.fetch(:format, :png).tap do |format|
      if Marcel::Magic.by_extension(format.to_s).nil?
        raise ArgumentError, "Invalid variant format (#{format.inspect})"
      end
    end
  end

  def content_type
    Marcel::MimeType.for(extension: format.to_s)
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  def digest
    OpenSSL::Digest::SHA1.base64digest Marshal.dump(transformations)
  end

  private
    def identity_for?(content_type)
      transformations.except(:format).empty? &&
        self.content_type == content_type
    end

    def transformer
      ActiveStorage.variant_transformer.new(transformations.except(:format))
    end
end
