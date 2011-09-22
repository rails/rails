require 'active_support/core_ext/class/attribute'
require 'active_support/core_ext/string/inflections'
require 'active_support/core_ext/file'
require 'action_view/helpers/tag_helper'

module ActionView
  module Helpers
    module AssetTagHelper

      class AssetIncludeTag
        include TagHelper

        attr_reader :config, :asset_paths
        class_attribute :expansions

        def self.inherited(base)
          base.expansions = { }
        end

        def initialize(config, asset_paths)
          @config = config
          @asset_paths = asset_paths
        end

        def asset_name
          raise NotImplementedError
        end

        def extension
          raise NotImplementedError
        end

        def custom_dir
          raise NotImplementedError
        end

        def asset_tag(source, options)
          raise NotImplementedError
        end

        def include_tag(*sources)
          options = sources.extract_options!.stringify_keys
          concat  = options.delete("concat")
          cache   = concat || options.delete("cache")
          recursive = options.delete("recursive")

          if concat || (config.perform_caching && cache)
            joined_name = (cache == true ? "all" : cache) + ".#{extension}"
            joined_path = File.join((joined_name[/^#{File::SEPARATOR}/] ? config.assets_dir : custom_dir), joined_name)
            unless config.perform_caching && File.exists?(joined_path)
              write_asset_file_contents(joined_path, compute_paths(sources, recursive))
            end
            asset_tag(joined_name, options)
          else
            sources = expand_sources(sources, recursive)
            ensure_sources!(sources) if cache
            sources.collect { |source| asset_tag(source, options) }.join("\n").html_safe
          end
        end

        private

          def path_to_asset(source, options = {})
            asset_paths.compute_public_path(source, asset_name.to_s.pluralize, options.merge(:ext => extension))
          end

          def path_to_asset_source(source)
            asset_paths.compute_source_path(source, asset_name.to_s.pluralize, extension)
          end

          def compute_paths(*args)
            expand_sources(*args).collect { |source| path_to_asset_source(source) }
          end

          def expand_sources(sources, recursive)
            if sources.first == :all
              collect_asset_files(custom_dir, ('**' if recursive), "*.#{extension}")
            else
              sources.inject([]) do |list, source|
                determined_source = determine_source(source, expansions)
                update_source_list(list, determined_source)
              end
            end
          end

          def update_source_list(list, source)
            case source
            when String
              list.delete(source)
              list << source
            when Array
              updated_sources = source - list
              list.concat(updated_sources)
            end
          end

          def ensure_sources!(sources)
            sources.each do |source|
              asset_file_path!(path_to_asset_source(source))
            end
          end

          def collect_asset_files(*path)
            dir = path.first

            Dir[File.join(*path.compact)].collect do |file|
              file[-(file.size - dir.size - 1)..-1].sub(/\.\w+$/, '')
            end.sort
          end

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
            mt = asset_paths.map { |p| File.mtime(asset_file_path!(p)) }.max
            File.utime(mt, mt, joined_asset_path)
          end

          def asset_file_path!(absolute_path, error_if_file_is_uri = false)
            if asset_paths.is_uri?(absolute_path)
              raise(Errno::ENOENT, "Asset file #{path} is uri and cannot be merged into single file") if error_if_file_is_uri
            else
              raise(Errno::ENOENT, "Asset file not found at '#{absolute_path}'" ) unless File.exist?(absolute_path)
              return absolute_path
            end
          end
      end

    end
  end
end
