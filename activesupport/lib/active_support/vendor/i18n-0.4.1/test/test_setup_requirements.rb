require 'optparse'

options = { :with => [] }
OptionParser.new do |o|
   o.on('-w', '--with DEPENDENCIES', 'Define dependencies') do |dep|
     options[:with] = dep.split(',').map { |group| group.to_sym }
   end
end.parse!

options[:with].each do |dep|
  case dep
  when :ar23, :'activerecord-2.3'
    gem 'activerecord', '~> 2.3'
  when :ar3, :'activerecord-3'
    gem 'activerecord', '~> 3'
  end
end

# Do not load the i18n gem from libraries like active_support, we'll load it from here :)
alias :gem_for_ruby_19 :gem # for 1.9. gives a super ugly seg fault otherwise
def gem(gem_name, *version_requirements)
  if gem_name =='i18n'
    puts "skipping loading the i18n gem ..."
    return
  end
  super(gem_name, *version_requirements)
end

def setup_mocha
  begin
    require 'mocha'
  rescue LoadError
    puts "skipping tests using mocha as mocha can't be found"
  end
end

def setup_active_record
  begin
    require 'active_record'
    ActiveRecord::Base.connection
    true
  rescue LoadError => e
    puts "can't use ActiveRecord backend because: #{e.message}"
  rescue ActiveRecord::ConnectionNotEstablished
    require 'i18n/backend/active_record'
    require 'i18n/backend/active_record/store_procs'
    connect_active_record
    true
  end
end

def connect_active_record
  ActiveRecord::Base.establish_connection(:adapter => "sqlite3", :database => ":memory:")
  ActiveRecord::Migration.verbose = false
  ActiveRecord::Schema.define(:version => 1) do
    create_table :translations do |t|
      t.string :locale
      t.string :key
      t.string :value
      t.string :interpolations
      t.boolean :is_proc, :default => false
    end
  end
end

def setup_rufus_tokyo
  require 'rubygems'
  require 'rufus/tokyo'
rescue LoadError => e
  puts "can't use KeyValue backend because: #{e.message}"
end