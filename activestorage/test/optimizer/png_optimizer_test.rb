# frozen_string_literal: true

require "test_helper"
require "database/setup"

require "active_storage/optimizer/web_image_optimizer"

class ActiveStorage::Optimizer::PngOptimizerTest < ActiveSupport::TestCase
  test "transforming with vips" do
    optimize_variants_with(:vips) do
      optimizer = ActiveStorage::Optimizer::PngOptimizer.new(nil)

      assert_equal "png", optimizer.transformations[:format]
      assert_equal 9, optimizer.transformations[:saver][:compression]
    end
  end

  test "transforming with image magick" do
    optimize_variants_with(:mini_magick) do
      optimizer = ActiveStorage::Optimizer::PngOptimizer.new(nil)

      assert_equal "png", optimizer.transformations[:format]
      assert_equal 75, optimizer.transformations[:saver][:quality]
    end
  end

  private
    def optimize_variants_with(processor)
      previous_processor, ActiveStorage.variant_processor = ActiveStorage.variant_processor, processor
      yield
    rescue LoadError
      ENV["CI"] ? raise : skip("Variant processor #{processor.inspect} is not installed")
    ensure
      ActiveStorage.variant_processor = previous_processor
    end
end
