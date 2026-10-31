# frozen_string_literal: true

# :markup: markdown

require "active_storage"
require "active_support/core_ext/object/blank"
require "active_support/core_ext/string/filters"

begin
  gem "mini_magick"
  require "mini_magick"
  ActiveStorage::MINIMAGICK_AVAILABLE = true # :nodoc:
rescue LoadError => error
  ActiveStorage::MINIMAGICK_AVAILABLE = false # :nodoc:
  raise error unless error.message.include?("mini_magick")
end

module ActiveStorage
  # Adds Active Storage's ImageMagick security policy to every ImageMagick process MiniMagick spawns.
  #
  # ImageMagick reads every `policy.xml` on its configuration search path and applies all of them,
  # so the shipped policy adds to the operator's policy rather than replacing it. `MAGICK_CONFIGURE_PATH`
  # prepends to that search path; a value the operator has already set, in the environment or in
  # `MiniMagick.cli_env`, is kept after the shipped directory.
  module ImageMagick
    POLICY_DIRECTORY = File.expand_path("image_magick", __dir__)

    # Called when Active Storage loads, and again after the application initializes, so that a
    # `MAGICK_CONFIGURE_PATH` or `MiniMagick.cli_env` set by an initializer or dotenv keeps the policy.
    def self.apply_policy # :nodoc:
      operator_paths = operator_paths(MiniMagick.cli_env["MAGICK_CONFIGURE_PATH"]).presence ||
        operator_paths(ENV["MAGICK_CONFIGURE_PATH"])

      MiniMagick.cli_env = MiniMagick.cli_env.merge("MAGICK_CONFIGURE_PATH" => configure_path(operator_paths)).freeze
    end

    def self.configure_path(operator_path)
      [ POLICY_DIRECTORY, *operator_paths(operator_path) ].join(File::PATH_SEPARATOR)
    end

    def self.operator_paths(path)
      Array(path).flat_map { |entry| entry.split(File::PATH_SEPARATOR) } - [ POLICY_DIRECTORY, "" ]
    end
    private_class_method :operator_paths
  end
end

ActiveStorage::MINIMAGICK_UNSECURABLE = ActiveStorage::MINIMAGICK_AVAILABLE && !MiniMagick.respond_to?(:cli_env=) # :nodoc:

module ActiveStorage
  # Raises when the installed mini_magick cannot apply the shipped ImageMagick security policy.
  # Called before Active Storage hands untrusted content to ImageMagick.
  def self.require_securable_mini_magick! # :nodoc:
    if MINIMAGICK_UNSECURABLE
      raise <<~ERROR.squish
        Active Storage's ImageMagick security policy requires mini_magick 5.1 or later. Please add
        `gem "mini_magick", "~> 5.1"` to your Gemfile, or use the :vips variant processor.
      ERROR
    end
  end
end

ActiveStorage::ImageMagick.apply_policy if ActiveStorage::MINIMAGICK_AVAILABLE && !ActiveStorage::MINIMAGICK_UNSECURABLE
