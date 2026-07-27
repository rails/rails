# frozen_string_literal: true

# :markup: markdown

require "active_storage"
require "active_support/core_ext/string/filters"

begin
  require "nokogiri"
rescue LoadError
  # Ensure nokogiri is loaded before vips, which also depends on libxml2.
  # See Nokogiri RFC: Stop exporting symbols:
  #   https://github.com/sparklemotion/nokogiri/discussions/2746
end

begin
  gem "ruby-vips"
  require "ruby-vips"
  ActiveStorage::VIPS_AVAILABLE = true # :nodoc:
rescue LoadError => error
  ActiveStorage::VIPS_AVAILABLE = false # :nodoc:
  raise error unless error.message.match?(/libvips|ruby-vips/)
end

if ActiveStorage::VIPS_AVAILABLE
  begin
    # image_processing 2.0 calls Vips.block_untrusted(true) itself when it loads, so it has to load
    # before the lines below. Leaving it to load later, when the transformer is autoloaded, would
    # disable the loaders again after an application's initializers had re-enabled them.
    require "image_processing/vips"
  rescue LoadError
    # image_processing is only needed to generate variants, not to analyze blobs.
  end

  unless Vips.respond_to?(:block_untrusted)
    raise <<~ERROR.squish
      libvips's unfuzzed operations are not safe to use with untrusted content, and Active Storage
      cannot disable them. Disabling them requires libvips 8.13 or later and ruby-vips 2.2.1 or
      later. Please upgrade libvips and ruby-vips, or remove the ruby-vips gem from your Gemfile.
    ERROR
  end

  Vips.block_untrusted(true)
end
