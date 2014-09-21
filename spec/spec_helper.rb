# encoding: UTF-8
require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test)
Bundler.require(:default, :test)
require 'pry'
require 'mysql2'
require 'net/http'
require 'json'
require 'tempfile'
ROOT = File.dirname(File.dirname(__FILE__))

if ENV['TRAVIS']
  require 'coveralls'
  Coveralls.wear!
end

$TESTING=true
$:.unshift File.join(File.dirname(__FILE__), '..', 'lib')

$rails_pids = {}
RAILS_PORT = 3000

TEST_ENV = {
  'RUBYOPT' => nil,
  'BUNDLE_GEMFILE' => nil,
  'BUNDLE_BIN_PATH' => nil,
  'GEM_HOME' => nil,
  'RAILS_ENV' => 'production'
}

RSpec.configure do |config|
  config.before(:all) do
    setup_rails(3.2)
    setup_rails(4.0)
  end

  config.before(:each) do
    killall
    expect(processlist.length).to eq(0)
  end

  config.after(:each) do
    stop_rails(3.2)
    stop_rails(4.0)
  end
end

def chdir_to_rails_dir(version)
  path = File.join(ROOT, "spec/rails/#{version}")
  Dir.chdir(path) do
    yield
  end
end

def setup_rails(version)
  env = TEST_ENV

  chdir_to_rails_dir(version) do
    system(env, 'bundle install --quiet')
    system(env, 'bundle exec rake db:create --quiet')
    system(env, 'bundle exec rake db:migrate --quiet')
  end
end

def start_rails(version, env = {})
  env = TEST_ENV.merge(env)

  chdir_to_rails_dir(version) do
    pid = spawn(env, "bundle exec rails s -b 127.0.0.1 -p #{RAILS_PORT}")
    $rails_pids[version] = pid
  end

  sleep (ENV['RAILS_START_WAIT'] || 7).to_i
end

def stop_rails(version)
  pid = $rails_pids[version]
  Process.kill('INT', pid) if pid
  sleep (ENV['RAILS_STOP_WAIT'] || 1).to_i
end

def mysql
  client = Mysql2::Client.new(host: '127.0.0.1', username: 'root')

  begin
    retval = yield(client)
  ensure
    client.close
  end

  retval
end

def processlist(db = nil)
  mysql do |client|
    rows = client.query("SHOW PROCESSLIST").to_a
    rows.select {|i| db ? i['db'] == db : i['db'] }
  end
end

def killall
  mysql do |client|
    rows = client.query("SHOW PROCESSLIST").to_a

    rows.select {|i| i['db'] }.each do |i|
      client.query("KILL #{i['Id']}")
    end
  end
end

def send_request
  Net::HTTP.start('127.0.0.1', RAILS_PORT) do |http|
    http.get('/items')
  end
end

def tempfile(content)
  Tempfile.open("#{File.basename __FILE__}.#{$$}") do |f|
    f << content
    f.flush
    f.rewind
    yield(f)
  end
end

def run_script(script)
  tempfile(script) do |f|
    Net::HTTP.start('127.0.0.1', RAILS_PORT) do |http|
      http.get("/run?file=#{f.path}").body
    end
  end
end
