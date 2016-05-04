module Rails
  class Forker
    autoload :Runner, 'rails/railtie/forker/runner'


    def runner=(runner)
      @runner=runner 
    end

    def options
      @options ||= {}
    end

    def options=(o)
      options.merge!(o)
    end

    def before_fork(&blk)
      @before_forks ||= []
      @before_forks << blk if blk
      @before_forks
    end

    def after_fork(&blk)
      @after_forks ||= []
      @after_forks << blk if blk
      @after_forks
    end


    def fork!(label, app)
      before_fork.each { |b| b.call(app) }
      Process.fork do
        $0 = "rails: #{label}"
        after_fork.each { |a| a.call(app) }
        begin
          run!
        rescue
          exit
        end
      end

    end

    def run!
      @runner::Runner.new(options).run!
    end 
  end
end
