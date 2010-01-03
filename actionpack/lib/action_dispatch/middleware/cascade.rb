module ActionDispatch
  class Cascade
    def self.new(*apps)
      apps = apps.flatten

      case apps.length
      when 0
        raise ArgumentError, "app is required"
      when 1
        apps.first
      else
        super(apps)
      end
    end

    def initialize(apps)
      @apps = apps
    end

    def call(env)
      result = nil
      @apps.each do |app|
        result = app.call(env)
        break unless result[1]["X-Cascade"] == "pass"
      end
      result
    end
  end
end
