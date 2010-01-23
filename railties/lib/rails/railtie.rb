module Rails
  # Railtie is the core of the Rails Framework and provides all the hooks and
  # methods you need to link your plugin into Rails.
  # 
  # What Railtie does is make every component of Rails a "plugin" and creates 
  # an API that exposes all the powers that the builtin components need
  # to any plugin author.
  # 
  # In fact, every major component of Rails (Action Mailer, Action Controller,
  # Action View, Active Record and Active Resource) are all now just plain
  # old plugins, so anything they can do, your plugin can do.
  # 
  # Developing a plugin for Rails does not _require_ any implementation of
  # Railtie, there is no fixed rule, but as a guideline, if your plugin works
  # by just being required before Rails boots, then there is no need for you
  # to hook into Railtie, but if you need to interact with the Rails framework
  # during boot, or after boot, then Railtie is what you need to do that
  # interaction.
  # 
  # For example, the following would need you to implement Railtie in your
  # plugin:
  # 
  # * creating initializers (including route insertion)
  # * modifying the render path (think HAML et al)
  # * adding Rails config.* keys to the environment
  # * setting up a subscriber to the Rails +ActiveSupport::Notifications+
  # * adding global Rake tasks into rails
  # * setting up a default configuration for the Application
  # 
  # Railtie gives you a central place to connect into the Rails framework.  If you
  # find yourself writing plugin code that is having to monkey patch parts of the
  # Rails framework to achieve something, there is probably a better, more elegant
  # way to do it through Railtie, if there isn't, then you have found a lacking
  # feature of Railtie, please lodge a ticket.
  # 
  # Implementing Railtie in your plugin is by creating a class Railtie in your
  # application that has your plugin name and making sure that this gets loaded
  # durng boot time of the Rails stack.
  # 
  # You can do this however you wish, but three straight forward ways are:
  # 
  # == For gems or plugins that are not used outside of Rails
  # 
  # * Create a Railtie subclass within your lib/my_plugin.rb file:
  #   
  #   # lib/my_plugin.rb
  #   module MyPlugin
  #     class Railtie < Rails::Railtie
  #     end
  #   end
  # 
  # * Pass in your plugin name
  # 
  #   # lib/my_plugin.rb
  #   module MyPlugin
  #     class Railtie < Rails::Railtie
  #       plugin_name :my_plugin
  #     end
  #   end
  #   
  # == For gems that could be used without Rails
  # 
  # * Create a file (say, lib/my_gem/railtie.rb) which contains class Railtie inheriting from
  #   Rails::Railtie and is namespaced to your gem:
  #
  #   # lib/my_gem/railtie.rb
  #   module MyGem
  #     class Railtie < Rails::Railtie
  #     end
  #   end
  # 
  # * Require your own gem as well as rails in this file:
  # 
  #   # lib/my_gem/railtie.rb
  #   require 'my_gem'
  #   require 'rails'
  # 
  #   module MyGem
  #     class Railtie < Rails::Railtie
  #     end
  #   end
  #   
  # * Give your gem a unique name:
  # 
  #   # lib/my_gem/railtie.rb
  #   require 'my_gem'
  #   require 'rails'
  # 
  #   module MyGem
  #     class Railtie < Rails::Railtie
  #       plugin_name :my_gem
  #     end
  #   end
  # 
  # * Make sure your Gem loads the railtie.rb file if Rails is loaded first, an easy
  #   way to check is by checking for the Rails constant which will exist if Rails
  #   has started:
  # 
  #   # lib/my_gem.rb
  #   module MyGem
  #     require 'lib/railtie' if defined?(Rails)
  #   end
  # 
  # * Or instead of doing the require automatically, you can ask your users to require
  #   it for you in their Gemfile:
  # 
  #   # #{USER_RAILS_ROOT}/Gemfile
  #   gem "my_gem", :require_as => ["my_gem", "my_gem/railtie"]
  #
  class Railtie
    include Initializable

    # Pass in the name of your plugin.  This is passed in as an underscored symbol.
    # 
    #   module MyPlugin
    #     class Railtie < Rails::Railtie
    #       plugin_name :my_plugin
    #     end
    #   end
    def self.plugin_name(plugin_name = nil)
      @plugin_name ||= name.demodulize.underscore
      @plugin_name = plugin_name if plugin_name
      @plugin_name
    end

    def self.inherited(klass)
      @plugins ||= []
      @plugins << klass unless klass == Plugin
    end

    def self.plugins
      @plugins
    end

    def self.plugin_names
      plugins.map { |p| p.plugin_name }
    end

    def self.config
      Configuration.default
    end

    def self.subscriber(subscriber)
      Rails::Subscriber.add(plugin_name, subscriber)
    end

    def self.rake_tasks(&blk)
      @rake_tasks ||= []
      @rake_tasks << blk if blk
      @rake_tasks
    end

    def self.generators(&blk)
      @generators ||= []
      @generators << blk if blk
      @generators
    end

    def rake_tasks
      self.class.rake_tasks
    end

    def generators
      self.class.generators
    end

    def load_tasks
      return unless rake_tasks
      rake_tasks.each { |blk| blk.call }
    end

    def load_generators
      return unless generators
      generators.each { |blk| blk.call }
    end
  end
end
