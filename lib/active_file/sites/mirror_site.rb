class ActiveFile::Sites::MirrorSite < ActiveFile::Site
  attr_reader :sites

  def initialize(sites:)
    @sites = sites
  end

  def upload(key, io)
    perform_across_sites :upload, key, io
  end

  def download(key)
    sites.detect { |site| site.exist?(key) }.download(key)
  end

  def delete(key)
    perform_across_sites :delete, key
  end

  def exist?(key)
    perform_across_sites(:exist?, key).any?
  end


  def byte_size(key)
    primary_site.byte_size(key)
  end

  def checksum(key)
    primary_site.checksum(key)
  end

  private
    def primary_site
      sites.first
    end

    def perform_across_sites(method, **args)
      # FIXME: Convert to be threaded
      sites.collect do |site|
        site.send method, **args
      end   
    end
end
