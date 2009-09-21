module Bundler
  class GemBundle < Array
    def download(repository)
      sort_by {|s| s.full_name.downcase }.each do |spec|
        spec.source.download(spec, repository)
      end

      self
    end
  end
end