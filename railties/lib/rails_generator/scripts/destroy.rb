require File.dirname(__FILE__) + '/../scripts'

module Rails::Generator::Scripts
  class Destroy < Base
    mandatory_options :command => :destroy

    protected
    def usage_message
      usage = "\nInstalled Generators\n"
      Rails::Generator::Base.sources.each do |source|
        label = source.label.to_s.capitalize
        names = source.names
        usage << "  #{label}: #{names.join(', ')}\n" unless names.empty?
      end

      usage << <<end_blurb

script/generate command. For instance, 'script/destroy migration CreatePost'
will delete the appropriate XXX_create_post.rb migration file in db/migrate,
while 'script/destroy scaffold Post' will delete the posts controller and
views, post model and migration, all associated tests, and the map.resources
:posts line in config/routes.rb.

For instructions on finding new generators, run script/generate.
end_blurb
      return usage
    end
  end
end
