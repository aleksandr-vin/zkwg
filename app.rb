# default example for async_sinatra gem
require 'sinatra/async'
require 'shotgun'
require 'haml'
require 'zk'
require 'json'

class App < Sinatra::Base
  register Sinatra::Async

  set :zookeeper_host, '192.168.56.110:2181'
  set :zk, ZK::Client::Threaded.new(settings.zookeeper_host)

  attr_reader :sid

  def self.childs (event)
    puts "========================"
    puts event
    if event.node_child?
      # do something on change
      puts settings.zk.children('/', :watch => true)
    else
      # we know it's a child event
    end
    puts "========================"

    # no next watch without next call, wtf?
    settings.zk.children('/', :watch => true)
  end

  def self.watch_children (path)
    puts "Registering watcher"
    settings.zk.register(path) do |event|
      App.childs(event)
    end
    # no run w/o next call, wtf?
    settings.zk.children(path, :watch => true)
  end

  aget '/' do
#    zk.children('/', :watch => true).each do |node|
#      puts "zk node: #{node}"
#    end

    ###############App.watch_children('/')

    #puts settings.zk.children('/', :watch => true)
  #  puts zk.create('/thin-conn', $$.to_s, :ephemeral => true)

    body { haml :ls }
  end
 
  aget '/delay/:n' do |n|
    EM.add_timer(n.to_i) { body { "delayed for #{n} seconds" } }
  end

  aget '/ls' do
    path = params[:path]
    path = '/' unless path

    room = EM::Channel.new
    
    @sid = room.subscribe do |event|
      if event.node_child?
        # do something on change
        names = settings.zk.children(path)
        body { JSON.dump [:path => path, :children => names] }
      else
        # we know it's a child event
        body { JSON.dump [:path => path, :event => event] }
      end

      room.unsubscribe(@sid)
    end

    puts "/ls: Registering watcher for #{path}"
    settings.zk.register(path) do |event|
      room.push(event)
    end

    # no run w/o next call, wtf?
    settings.zk.children(path, :watch => true)
  end
end
