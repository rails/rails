#!/usr/bin/env ruby -KU

TIMES = (ENV['N'] || 10000).to_i
require 'rubygems'

gem 'addressable',  '~>2.0'
gem 'faker',        '~>0.3.1'
gem 'rbench',       '~>0.2.3'

require 'addressable/uri'
require 'faker'
require 'rbench'

require File.expand_path("../../../load_paths", __FILE__)
require "active_record"

conn = { :adapter => 'mysql',
  :database => 'activerecord_unittest',
  :username => 'rails', :password => '',
  :encoding => 'utf8' }

conn[:socket] = Pathname.glob(%w[
  /opt/local/var/run/mysql5/mysqld.sock
  /tmp/mysqld.sock
  /tmp/mysql.sock
  /var/mysql/mysql.sock
  /var/run/mysqld/mysqld.sock
]).find { |path| path.socket? }.to_s

ActiveRecord::Base.establish_connection(conn)

class User < ActiveRecord::Base
  connection.create_table :users, :force => true do |t|
    t.string :name, :email
    t.timestamps
  end

  has_many :exhibits
end

class Exhibit < ActiveRecord::Base
  connection.create_table :exhibits, :force => true do |t|
    t.belongs_to :user
    t.string :name
    t.text :notes
    t.timestamps
  end

  belongs_to :user

  def look; attributes end
  def feel; look; user.name end

  def self.look(exhibits) exhibits.each { |e| e.look } end
  def self.feel(exhibits) exhibits.each { |e| e.feel } end
end

sqlfile = File.expand_path("../performance.sql", __FILE__)

if File.exists?(sqlfile)
  mysql_bin = %w[mysql mysql5].detect { |bin| `which #{bin}`.length > 0 }
  `#{mysql_bin} -u #{conn[:username]} #{"-p#{conn[:password]}" unless conn[:password].blank?} #{conn[:database]} < #{sqlfile}`
else
  puts 'Generating data...'

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
      :created_at => today,
      :name       => Faker::Name.name,
      :email      => Faker::Internet.email
    )

    Exhibit.create(
      :created_at => today,
      :name       => Faker::Company.name,
      :user       => user,
      :notes      => notes
    )
  end

  mysqldump_bin = %w[mysqldump mysqldump5].select { |bin| `which #{bin}`.length > 0 }
  `#{mysqldump_bin} -u #{conn[:username]} #{"-p#{conn[:password]}" unless conn[:password].blank?} #{conn[:database]} exhibits users > #{sqlfile}`
end

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

  report 'Model.first' do
    ar { Exhibit.first.look }
  end

  report 'Model.all limit(100)', (TIMES / 10).ceil do
    ar { Exhibit.look Exhibit.limit(100) }
  end

  report 'Model.all limit(100) with relationship', (TIMES / 10).ceil do
    ar { Exhibit.feel Exhibit.limit(100).includes(:user) }
  end

  report 'Model.all limit(10,000)', (TIMES / 1000).ceil do
    ar { Exhibit.look Exhibit.limit(10000) }
  end

  exhibit = {
    :name       => Faker::Company.name,
    :notes      => Faker::Lorem.paragraphs.join($/),
    :created_at => Date.today
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
    ar { Exhibit.first.update_attributes(:name => 'bob') }
  end

  report 'Resource#destroy' do
    ar { Exhibit.first.destroy }
  end

  report 'Model.transaction' do
    ar { Exhibit.transaction { Exhibit.new } }
  end

  report 'Model.find(id)' do
    id = Exhibit.first.id
    ar { Exhibit.find(id) }
  end

  report 'Model.find_by_sql' do
    ar { Exhibit.find_by_sql("SELECT * FROM exhibits WHERE id = #{(rand * 1000 + 1).to_i}").first }
  end

  report 'Model.log', (TIMES * 10) do
    ar { Exhibit.connection.send(:log, "hello", "world") {} }
  end

  report 'AR.execute(query)', (TIMES / 2) do
    ar { ActiveRecord::Base.connection.execute("Select * from exhibits where id = #{(rand * 1000 + 1).to_i}") }
  end

  summary 'Total'
end

ActiveRecord::Migration.drop_table "exhibits"
ActiveRecord::Migration.drop_table "users"
