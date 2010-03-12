class File
  unless File.allocate.respond_to?(:to_path)
    alias to_path path
  end
end