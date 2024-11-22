# frozen_string_literal: true

module Rails
  class Application
    class PatchLoader
      DECORATED_CLASS_PATTERN = /(?<decorated_class>[A-Z][a-zA-Z:]+)(\.prepend[\s(])/

      attr_reader :base_path, :autoloader

      def initialize(base_path, autoloader: Rails.autoloaders.main)
        @base_path = base_path
        @autoloader = autoloader
      end

      def call
        autoloader.dirs.grep(/#{base_path}/).each do |path|
          Pathname.new(path).glob("**/*_patch.rb") do |patch_path|
            # Match all the classes that are prepended in the file
            matches = File.read(patch_path).scan(DECORATED_CLASS_PATTERN).flatten

            # Don't do a thing if there's no prepending.
            return unless matches.present?

            # For each unique match, make sure we load the decorator when the base class is loaded
            matches.uniq.each do |decorated_class|
              # Zeitwerk tells us which constant it expects a file to provide.
              decorator_constant = autoloader.cpath_expected_at(patch_path)
              # Sprinkle some debugging.
              Rails.logger.debug("Preparing to autoload #{decorated_class} with #{decorator_constant}")
              # If the class has not been loaded, we can add a hook to load the decorator when it is.
              # Multiple hooks are no problem, as long as all decorators are namespaced appropriately.
              autoloader.on_load(decorated_class) do |base|
                Rails.logger.debug("Loading #{decorator_constant} in order to modify #{base}")
                decorator_constant.constantize
              end
            end
          end
        end
      end
    end
  end
end
