# frozen_string_literal: true

# A set of transformations that can be applied to a blob to create a variant. This class is exposed via
# the ActiveStorage::Blob#variant method and should rarely be used directly.
#
# In case you do need to use this directly, it's instantiated using a hash of transformations where
# the key is the command and the value is the arguments. Example:
#
#   ActiveStorage::Variation.new(resize: "100x100", monochrome: true, trim: true, rotate: "-90")
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
    @transformations = transformations
  end

  # Accepts a File object, performs the +transformations+ against it, and
  # saves the transformed image into a temporary file. If +format+ is specified
  # it will be the format of the result image, otherwise the result image
  # retains the source format.
  def transform(file, format: nil)
    ActiveSupport::Notifications.instrument("transform.active_storage") do
      if processor
        image_processing_transform(file, format)
      else
        mini_magick_transform(file, format)
      end
    end
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  private
    # Applies image transformations using the ImageProcessing gem.
    def image_processing_transform(file, format)
      operations = transformations.inject([]) do |list, (name, argument)|
        if name.to_s == "combine_options"
          ActiveSupport::Deprecation.warn("The ImageProcessing ActiveStorage variant backend doesn't need :combine_options, as it already generates a single MiniMagick command. In Rails 6.1 :combine_options will not be supported anymore.")
          list.concat argument.to_a
        else
          list << [name, argument]
        end
      end

      processor
        .source(file)
        .loader(page: 0)
        .convert(format)
        .apply(operations)
        .call
    end

    # Applies image transformations using the MiniMagick gem.
    def mini_magick_transform(file, format)
      image = MiniMagick::Image.new(file.path, file)

      transformations.each do |name, argument_or_subtransformations|
        image.mogrify do |command|
          if name.to_s == "combine_options"
            argument_or_subtransformations.each do |subtransformation_name, subtransformation_argument|
              pass_transform_argument(command, subtransformation_name, subtransformation_argument)
            end
          else
            pass_transform_argument(command, name, argument_or_subtransformations)
          end
        end
      end

      image.format(format) if format

      image.tempfile.tap(&:open)
    end

    # Returns the ImageProcessing processor class specified by `ActiveStorage.processor`.
    def processor
      require "image_processing"
      ImageProcessing.const_get(ActiveStorage.processor.to_s.camelize) if ActiveStorage.processor
    rescue LoadError
      ActiveSupport::Deprecation.warn("Using mini_magick gem directly is deprecated and will be removed in Rails 6.1. Please add `gem 'image_processing', '~> 1.2'` to your Gemfile.")
    end

    def pass_transform_argument(command, method, argument)
      if eligible_argument?(argument)
        command.public_send(method, argument)
      else
        command.public_send(method)
      end
    end

    def eligible_argument?(argument)
      argument.present? && argument != true
    end
end
