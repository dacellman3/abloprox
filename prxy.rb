require 'webrick' 
require 'webrick/httpproxy' 
require 'set'

class AbloProx < WEBrick::HTTPProxyServer
  
  def initialize(options)
    super
    @blocked = Set.new
  end
  
  def add_blocklist(filename)
    File.open(filename).each_line do |line|
      block line
    end
  end
  
  def block(host)
    host.strip!
    return if host == nil || host.empty? || host.start_with?('#')
    @blocked.add? host.strip
  end
  
  def do_GET(req, res)
    #puts req.host
    if blocked? req.host
      logger.info "BLOCK #{req.host}"
      return no_response
    else
      super
    end
  end
  
  def do_CONNECT(req, res)
    host = req.header["host"].first
    if blocked? host
      logger.info "BLOCK #{host}"
      return no_response
    else
      super
    end
  end
  
  private
  
  def blocked?(host)
    h = host.split('.')
    while !h.empty?
      hostname = h.join '.'
      return true if @blocked.include?(hostname)
      h.shift
    end
    false
  end
  
  def no_response
    r = WEBrick::HTTPResponse.new( { :HTTPVersion => "1.1"} )
    r.status = 204
    r
  end
  
end

if ARGV.empty?
  port = 3126
elsif ARGV.size == 1
  port = ARGV[0].to_i
else
  puts 'Usage: prxy.rb [port]'
  exit 1
end

s = AbloProx.new(:Port => port, :AccessLog => [])

# Shutdown functionality
trap("INT"){s.shutdown}

s.add_blocklist 'adservers.txt'
s.add_blocklist 'analytics.txt'
s.add_blocklist 'evil.txt'

s.start
