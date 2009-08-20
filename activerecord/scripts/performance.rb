#!/usr/bin/env ruby -KU

$:.unshift(File.dirname(__FILE__) + '/../lib')

require 'ftools'
require 'rubygems'

gem 'addressable',  '~>2.0'
gem 'faker',        '~>0.3.1'
gem 'rbench',       '~>0.2.3'

require 'active_record'
require 'logger'
require 'active_support'
require 'addressable/uri'
require 'faker'
require 'rbench'

socket_file = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  tmp/mysqld.sock
  /tmp/mysqld.sock
  tmp/mysql.sock
  /tmp/mysql.sock
  /var/mysql/mysql.sock
  /var/run/mysqld/mysqld.sock
]).find { |path| path.socket? }

configuration_options = {
  :adapter => 'mysql',
  :username => 'rails',
  :password => '',
  :database => 'activerecord_unittest',
}

configuration_options[:socket] = socket_file unless socket_file.nil?

if configuration_options[:adapter]
  sqlfile       = File.join(File.dirname(__FILE__), 'tmp', 'performance.sql')
  mysql_bin     = %w[ mysql mysql5 ].select { |bin| `which #{bin}`.length > 0 }
  mysqldump_bin = %w[ mysqldump mysqldump5 ].select { |bin| `which #{bin}`.length > 0 }
end

ActiveRecord::Base.logger = Logger.new(File.join(File.dirname(__FILE__), 'performance.log'))
ActiveRecord::Base.logger.level = 0

ActiveRecord::Base.establish_connection(configuration_options)

class Exhibit < ActiveRecord::Base #:nodoc:
  belongs_to :user
end

class User < ActiveRecord::Base #:nodoc:
  has_many :exhibits
end

ActiveRecord::Migration.create_table :users, :force => true do |t|
  t.string    :name, :email
  t.datetime  :created_on
end

ActiveRecord::Migration.create_table :exhibits, :force => true do |t|
  t.string    :name
  t.integer   :user_id
  t.text      :notes
  t.datetime  :created_on
end

Exhibit.find_by_sql('SELECT 1')

def touch_attributes(*exhibits)
  exhibits.flatten.each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
  end
end

def touch_relationships(*exhibits)
  exhibits.flatten.each do |exhibit|
    exhibit.id
    exhibit.name
    exhibit.created_on
    exhibit.user
  end
end

c = configuration_options

if sqlfile && File.exists?(sqlfile)
  puts "Found data-file. Importing from #{sqlfile}"
  `#{mysql_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} < #{sqlfile}`
else
  puts 'Generating data for benchmarking...'

  # pre-compute the insert statements and fake data compilation,
  # so the benchmarks below show the actual runtime for the execute
  # method, minus the setup steps

  # Using the same paragraph for all exhibits because it is very slow
  # to generate unique paragraphs for all exhibits.
  notes = Faker::Lorem.paragraphs.join($/)
  today = Date.today

  puts 'Inserting 10,000 users and exhibits...'
  10_000.times do
    user = User.create(
      :created_on => today,
      :name       => Faker::Name.name,
      :email      => Faker::Internet.email
    )

    Exhibit.create(
      :created_on => today,
      :name       => Faker::Company.name,
      :user       => user,
      :notes      => notes
    )
  end

  if sqlfile
    answer = nil
    until answer && answer[/^$|y|yes|n|no/]
      print('Would you like to dump data into tmp/performance.sql (for faster setup)? [Yn]');
      STDOUT.flush
      answer = gets
    end

    if answer[/^$|y|yes/]
      File.makedirs(File.dirname(sqlfile))
      `#{mysqldump_bin} -u #{c[:username]} #{"-p#{c[:password]}" unless c[:password].blank?} #{c[:database]} exhibits users > #{sqlfile}`
      puts "File saved\n"
    end
  end
end

TIMES = ENV.key?('x') ? ENV['x'].to_i : 10_000

puts 'You can specify how many times you want to run the benchmarks with rake:perf x=(number)'
puts 'Some tasks will be run 10 and 1000 times less than (number)'
puts "Benchmarks will now run #{TIMES} times"
# Inform about slow benchmark
# answer = nil
# until answer && answer[/^$|y|yes|n|no/]
#   print("A slow benchmark exposing problems with SEL is newly added. It takes approx. 20s\n");
#   print("you have scheduled it to run #{TIMES / 100} times.\nWould you still include the particular benchmark? [Yn]")
#   STDOUT.flush
#   answer = gets
# end
# run_rel_bench = answer[/^$|y|yes/] ? true : false


RBench.run(TIMES) do

  column :times
  column :ar

  report 'Model#id', (TIMES * 100).ceil do
    ar_obj = Exhibit.find(1)

    ar { ar_obj.id }
  end

  report 'Model.new (instantiation)' do
    ar { Exhibit.new }
  end

  report 'Model.new (setting attributes)' do
    attrs = { :name => 'sam' }
    ar { Exhibit.new(attrs) }
  end

  report 'Model.get specific (not cached)' do
    ActiveRecord::Base.uncached { ar { touch_attributes(Exhibit.find(1)) } }
  end

  report 'Model.get specific (cached)' do
    ActiveRecord::Base.cache     { ar { touch_attributes(Exhibit.find(1)) } }
  end

  report 'Model.first' do
    ar { touch_attributes(Exhibit.first) }
  end

  report 'Model.all limit(100)', (TIMES / 10).ceil do
    ar { touch_attributes(Exhibit.find(:all, :limit => 100)) }
  end

  report 'Model.all limit(100) with relationship', (TIMES / 10).ceil do
    ar { touch_relationships(Exhibit.find(:all, :limit => 100, :include => [ :user ])) }
  end

  report 'Model.all limit(10,000)', (TIMES / 1000).ceil do
    ar { touch_attributes(Exhibit.find(:all, :limit => 10_000)) }
  end

  exhibit = {
    :name       => Faker::Company.name,
    :notes      => Faker::Lorem.paragraphs.join($/),
    :created_on => Date.today
  }

  report 'Model.create' do
    ar { Exhibit.create(exhibit) }
  end

  report 'Resource#attributes=' do
    attrs_first  = { :name => 'sam' }
    attrs_second = { :name => 'tom' }
    ar { exhibit = Exhibit.new(attrs_first); exhibit.attributes = attrs_second }
  end

  report 'Resource#update' do
    ar { Exhibit.find(1).update_attributes(:name => 'bob') }
  end

  report 'Resource#destroy' do
    ar { Exhibit.first.destroy }
  end

  report 'Model.transaction' do
    ar { Exhibit.transaction { Exhibit.new } }
  end

  summary 'Total'
end

ActiveRecord::Migration.drop_table "exhibits"
ActiveRecord::Migration.drop_table "users"
