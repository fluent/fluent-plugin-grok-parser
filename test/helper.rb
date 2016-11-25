require "fluent/test"
require "fluent/test/helpers"
require "fluent/test/driver/input"
require "fluent/test/driver/parser"

Test::Unit::TestCase.include(Fluent::Test::Helpers)

def unused_port
  s = TCPServer.open(0)
  port = s.addr[1]
  s.close
  port
end

def ipv6_enabled?
  require "socket"

  begin
    TCPServer.open("::1", 0)
    true
  rescue
    false
  end
end
