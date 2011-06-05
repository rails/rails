require 'yaml'
require 'erubis'
require 'fileutils'

module ARTest
  class << self
    def config
      @config ||= read_config
    end

    private

    def read_config
      unless File.exist?(TEST_ROOT + '/config.yml')
        FileUtils.cp TEST_ROOT + '/config.example.yml', TEST_ROOT + '/config.yml'
      end

      raw = File.read(TEST_ROOT + '/config.yml')
      erb = Erubis::Eruby.new(raw)
      expand_config(YAML.parse(erb.result(binding)).transform)
    end

    def expand_config(config)
      config['connections'].each do |adapter, connection|
        dbs = [['arunit', 'activerecord_unittest'], ['arunit2', 'activerecord_unittest2']]
        dbs.each do |name, dbname|
          unless connection[name].is_a?(Hash)
            connection[name] = { 'database' => connection[name] }
          end

          connection[name]['database'] ||= dbname
          connection[name]['adapter']  ||= adapter
        end
      end

      config
    end
  end
end
