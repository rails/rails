module Bundler
  class GemBundle < Array
    def download(directory)
      FileUtils.mkdir_p(directory)

      current = Dir[File.join(directory, "cache", "*.gem*")]

      each do |spec|
        cached = File.join(directory, "cache", "#{spec.full_name}.gem")

        unless File.file?(cached)
          Gem::RemoteFetcher.fetcher.download(spec, spec.source, directory)
        end

        current.delete(cached)
      end

      current.each { |file| File.delete(file) }

      self
    end
  end
end