# frozen_string_literal: true

require "bundler/setup"
require "active_support"
require "active_support/test_case"
require "active_support/testing/autorun"
require "active_storage"
require "active_storage/transformers/image_processing_transformer"

# Ensure validation config is loaded
ActiveStorage.supported_image_processing_methods = %w[resize resize_to_limit resize_to_fit crop]
ActiveStorage.unsupported_image_processing_arguments = %w[-debug -display -distribute-cache -help -path -print -set -verbose -version -write -write-mask]

class ActiveStorage::Transformers::ImageProcessingTransformerValidationTest < ActiveSupport::TestCase
  UnsupportedMethod = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingMethod
  UnsupportedArgument = ActiveStorage::Transformers::ImageProcessingTransformer::UnsupportedImageProcessingArgument

  setup do
    @transformer_class = Class.new(ActiveStorage::Transformers::ImageProcessingTransformer) do
      public :validate_transformation, :validate_arg_string, :validate_arg_array, :validate_arg_hash
    end
    @transformer = @transformer_class.allocate
  end

  # --- Unsupported method name ---

  test "rejects unsupported transformation method" do
    assert_raises(UnsupportedMethod) do
      @transformer.validate_transformation(:instance_eval, "`id > /tmp/pwned`")
    end
  end

  test "rejects system method" do
    assert_raises(UnsupportedMethod) do
      @transformer.validate_transformation(:system, "touch /tmp/dangerous")
    end
  end

  test "rejects send method" do
    assert_raises(UnsupportedMethod) do
      @transformer.validate_transformation(:send, "system")
    end
  end

  test "rejects public_send method" do
    assert_raises(UnsupportedMethod) do
      @transformer.validate_transformation(:public_send, "system")
    end
  end

  test "allows supported transformation method" do
    assert_nothing_raised do
      @transformer.validate_transformation(:resize, "100x100")
    end
  end

  # --- Dangerous argument strings ---

  test "rejects dangerous -write argument string" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, "-write /tmp/file.erb")
    end
  end

  test "rejects dangerous -path argument string" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, "-PaTh /tmp/file.erb")
    end
  end

  # --- Dangerous argument arrays ---

  test "rejects dangerous argument in array" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, [123, "-write", "/tmp/file.erb"])
    end
  end

  test "rejects dangerous argument in nested array" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, [123, ["-write", "/tmp/file.erb"]])
    end
  end

  # --- Dangerous argument hashes ---

  test "rejects dangerous argument in hash key" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, { "-write": "/tmp/file.erb" })
    end
  end

  test "rejects dangerous argument in hash value" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, { something: "-write /tmp/file.erb" })
    end
  end

  test "rejects dangerous argument in nested hash" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, { something: { "-write": "/tmp/file.erb" } })
    end
  end

  test "rejects dangerous argument in array inside hash" do
    assert_raises(UnsupportedArgument) do
      @transformer.validate_transformation(:resize, { something: ["-write", "/tmp/file.erb"] })
    end
  end

  # --- RCE via instance_eval (CVE-2025-24293) ---

  test "rejects instance_eval method (RCE vector)" do
    assert_raises(UnsupportedMethod) do
      @transformer.validate_transformation(:instance_eval, "`id > /tmp/pwned`")
    end
  end

  test "rejects __send__ method" do
    assert_raises(UnsupportedMethod) do
      @transformer.validate_transformation(:__send__, "system")
    end
  end

  # --- Valid transformations pass ---

  test "allows resize_to_limit with valid dimensions" do
    assert_nothing_raised do
      @transformer.validate_transformation(:resize_to_limit, [100, 100])
    end
  end

  test "allows crop with valid string" do
    assert_nothing_raised do
      @transformer.validate_transformation(:crop, "100x100+0+0")
    end
  end
end
