# default example for async_sinatra gem
require 'sinatra/async'
require 'haml'
require 'zk'
require 'json'
require 'logger'


class App < Sinatra::Base
  register Sinatra::Async

  logger = Logger.new(STDOUT)

  set :zookeeper_host, '127.0.0.1:2181'
  set :zk, ZK::Client::Threaded.new(settings.zookeeper_host)
  
  attr_reader :sid

  aget '/' do
    body { haml :ls }
  end

  aget '/ls' do
    path = params[:path]
    path = '/' unless path

    puts "/ls: Registering watcher for #{path}"
    settings.zk.register(path) do |event|
      if event.node_child?
        # do something on change
        names = settings.zk.children(path)
        body { JSON.dump [:path => path, :children => names] }
      else
        # we know it's a child event
        body { JSON.dump [:path => path, :event => event] }
      end
    end

    # no run w/o next call, wtf?
    settings.zk.children(path, :watch => true)
  end
end
