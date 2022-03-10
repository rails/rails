# frozen_string_literal: true

# A set of transformations that can be applied to a blob to create a variant. This class is exposed via
# the ActiveStorage::Blob#variant method and should rarely be used directly.
#
# In case you do need to use this directly, it's instantiated using a hash of transformations where
# the key is the command and the value is the arguments. Example:
#
#   ActiveStorage::Variation.new(resize: "100x100", monochrome: true, trim: true, rotate: "-90")
#
# You can also combine multiple transformations in one step, e.g. for center-weighted cropping:
#
#   ActiveStorage::Variation.new(combine_options: {
#     resize: "100x100^",
#     gravity: "center",
#     crop: "100x100+0+0",
#   })
#
# A list of all possible transformations is available at https://www.imagemagick.org/script/mogrify.php.
class ActiveStorage::Variation
  attr_reader :transformations

  class UnsupportedImageProcessingMethod < StandardError; end
  class UnsupportedImageProcessingArgument < StandardError; end

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

  # Accepts an open MiniMagick image instance, like what's returned by <tt>MiniMagick::Image.read(io)</tt>,
  # and performs the +transformations+ against it. The transformed image instance is then returned.
  def transform(image)
    ActiveSupport::Notifications.instrument("transform.active_storage") do
      transformations.each do |name, argument_or_subtransformations|
        validate_transformation(name, argument_or_subtransformations)
        image.mogrify do |command|
          if name.to_s == "combine_options"
            argument_or_subtransformations.each do |subtransformation_name, subtransformation_argument|
              validate_transformation(subtransformation_name, subtransformation_argument)
              pass_transform_argument(command, subtransformation_name, subtransformation_argument)
            end
          else
            validate_transformation(name, argument_or_subtransformations)
            pass_transform_argument(command, name, argument_or_subtransformations)
          end
        end
      end
    end
  end

  # Returns a signed key for all the +transformations+ that this variation was instantiated with.
  def key
    self.class.encode(transformations)
  end

  private
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

    def validate_transformation(name, argument)
      method_name = name.to_s.gsub("-","_")

      unless ActiveStorage.supported_image_processing_methods.any? { |method| method_name == method }
        raise UnsupportedImageProcessingMethod, <<~ERROR.squish
          One or more of the provided transformation methods is not supported.
        ERROR
      end

      if argument.present?
        if argument.is_a?(String) || argument.is_a?(Symbol)
          validate_arg_string(argument)
        elsif argument.is_a?(Array)
          validate_arg_array(argument)
        elsif argument.is_a?(Hash)
          validate_arg_hash(argument)
        end
      end
    end

    def validate_arg_string(argument)
      if ActiveStorage.unsupported_image_processing_arguments.any? { |bad_arg| argument.to_s.downcase.include?(bad_arg) }; raise UnsupportedImageProcessingArgument end
    end

    def validate_arg_array(argument)
      argument.each do |arg|
        if arg.is_a?(Integer) || arg.is_a?(Float)
          next
        elsif arg.is_a?(String) || arg.is_a?(Symbol)
          validate_arg_string(arg)
        elsif arg.is_a?(Array)
          validate_arg_array(arg)
        elsif arg.is_a?(Hash)
          validate_arg_hash(arg)
        end
      end
    end

    def validate_arg_hash(argument)
      argument.each do |key, value|
        validate_arg_string(key)

        if value.is_a?(Integer) || value.is_a?(Float)
          next
        elsif value.is_a?(String) || value.is_a?(Symbol)
          validate_arg_string(value)
        elsif value.is_a?(Array)
          validate_arg_array(value)
        elsif value.is_a?(Hash)
          validate_arg_hash(value)
        end
      end
    end
end
