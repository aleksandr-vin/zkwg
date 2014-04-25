# default example for async_sinatra gem
require 'sinatra/async'
require 'haml'
require 'json'
require 'logger'
require 'zk-eventmachine'


class App < Sinatra::Base
  register Sinatra::Async

  logger = Logger.new(STDOUT)

  set :zookeeper_host, '127.0.0.1:2181'

  @@zkem = ZK::ZKEventMachine::Client.new(settings.zookeeper_host)
  logger.debug("Connecting to Zookeeper #{settings.zookeeper_host}")
  @@zkem.connect do
    logger.info("Zookeeper #{settings.zookeeper_host} is online")
  end
 
  aget '/' do
    body { haml :ls }
  end

  aget '/ls' do
    path = params[:path]
    path = '/' unless path

    logger.debug("Registering Zookeeper watcher for #{path}")
    @sub = @@zkem.register(path) do |event|
      logger.debug("#{event.event_name} from Zookeeper arrived, for path: #{event.path}")
      @sub.unsubscribe
      if event.node_child?
        @@zkem.children(event.path).callback do |val,stat|
          logger.debug("ZK: #{event.path} children: #{JSON.dump val}")
          body { JSON.dump [:path => event.path, :children => val, :stat => stat] }
        end.errback do |ex|
          logger.error("ZK: #{event.path} exception from children: #{ex}")
          body { JSON.dump [:path => event.path, :excepton => ex] }
        end
      else
        body { JSON.dump [:path => event.path, :event => event] }
      end
    end

    # no run w/o next call, wtf?
    @@zkem.children(path, :watch => true).errback do |ex|
      logger.error("ZK: #{path} exception from children: #{ex}")
      body { JSON.dump [:path => event.path, :excepton => ex] }
    end
  end
end