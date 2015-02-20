namespace :cache_digests do
  desc 'Lookup nested dependencies for TEMPLATE (like messages/show or comments/_comment.html)'
  task :nested_dependencies => :environment do
    abort 'You must provide TEMPLATE for the task to run' unless ENV['TEMPLATE'].present?
    puts JSON.pretty_generate ActionView::Digestor.new(name: CacheDigests.template_name, finder: CacheDigests.finder).nested_dependencies
  end

  desc 'Lookup first-level dependencies for TEMPLATE (like messages/show or comments/_comment.html)'
  task :dependencies => :environment do
    abort 'You must provide TEMPLATE for the task to run' unless ENV['TEMPLATE'].present?
    puts JSON.pretty_generate ActionView::Digestor.new(name: CacheDigests.template_name, finder: CacheDigests.finder).dependencies
  end

  class CacheDigests
    def self.template_name
      ENV['TEMPLATE'].split('.', 2).first
    end

    def self.finder
      ApplicationController.new.lookup_context
    end
  end
end
