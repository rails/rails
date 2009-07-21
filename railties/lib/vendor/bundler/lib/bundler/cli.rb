module Bundler
  module CLI

    def default_manifest
      current = Pathname.new(Dir.pwd)

      begin
        manifest = current.join("Gemfile")
        return manifest.to_s if File.exist?(manifest)
        current = current.parent
      end until current.root?
      nil
    end

    module_function :default_manifest

    def default_path
      Pathname.new(File.dirname(default_manifest)).join("vendor").join("gems").to_s
    end

    module_function :default_path

  end
end