require 'active_support/concern'
require 'active_support/inflector'

module ActionView
  module Helpers
    module AssetTagHelper

      module HelperMethods
        private
        def asset_path(asset_type, extension = nil)
          define_method("#{asset_type}_path") do |source|
            compute_public_path(source, asset_type.to_s.pluralize, extension)
          end
          alias_method :"path_to_#{asset_type}", :"#{asset_type}_path" # aliased to avoid conflicts with a *_path named route
        end
      end

      module SharedHelpers
        def determine_source(source, collection)
          case source
          when Symbol
            collection[source] || raise(ArgumentError, "No expansion found for #{source.inspect}")
          else
            source
          end
        end

        def join_asset_file_contents(paths)
          paths.collect { |path| File.read(asset_file_path!(path, true)) }.join("\n\n")
        end

        def write_asset_file_contents(joined_asset_path, asset_paths)
          FileUtils.mkdir_p(File.dirname(joined_asset_path))
          File.atomic_write(joined_asset_path) { |cache| cache.write(join_asset_file_contents(asset_paths)) }

          # Set mtime to the latest of the combined files to allow for
          # consistent ETag without a shared filesystem.
          mt = asset_paths.map { |p| File.mtime(asset_file_path(p)) }.max
          File.utime(mt, mt, joined_asset_path)
        end

        def asset_file_path(path)
          File.join(config.assets_dir, path.split('?').first)
        end

        def asset_file_path!(path, error_if_file_is_uri = false)
          if is_uri?(path)
            raise(Errno::ENOENT, "Asset file #{path} is uri and cannot be merged into single file") if error_if_file_is_uri
          else
            absolute_path = asset_file_path(path)
            raise(Errno::ENOENT, "Asset file not found at '#{absolute_path}'" ) unless File.exist?(absolute_path)
            return absolute_path
          end
        end

        def collect_asset_files(*path)
          dir = path.first

          Dir[File.join(*path.compact)].collect do |file|
            file[-(file.size - dir.size - 1)..-1].sub(/\.\w+$/, '')
          end.sort
        end
      end

    end
  end
end