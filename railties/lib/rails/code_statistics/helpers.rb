module CodeStatistics::Helpers #:nodoc:
  extend self

  def eager_loaded_paths
    config = Rails.application.config
    paths = (config.autoload_paths + config.eager_load_paths + config.autoload_once_paths).uniq
    paths = remove_child_paths(paths)
    convert_to_relative(paths, config.root)
  end

  def dir_label(dir)
    if dir =~ /app\/(.+)/
      $1.gsub("/", " ").titleize
    else
      dir.pluralize.titleize
    end
  end

  private
    def remove_child_paths(paths)
      paths.reject do |path|
        paths.any? { |child| child != path && path.starts_with?(child) }
      end
    end

    def convert_to_relative(paths, root)
      paths.map { |n| Pathname.new(n).relative_path_from(root).to_s }
    end
end
