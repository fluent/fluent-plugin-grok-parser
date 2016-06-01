require 'helper'
require 'fluent/test'
require 'fluent/plugin/in_tcp'

class TcpInputWithGrokTest < Test::Unit::TestCase
  if defined?(ServerEngine)
    class << self
      def startup
        socket_manager_path = ServerEngine::SocketManager::Server.generate_path
        @server = ServerEngine::SocketManager::Server.open(socket_manager_path)
        ENV['SERVERENGINE_SOCKETMANAGER_PATH'] = socket_manager_path.to_s
      end

      def shutdown
        @server.close
      end
    end
  end

  def setup
    Fluent::Test.setup
  end

  PORT = unused_port
  BASE_CONFIG = %[
    port #{PORT}
    tag tcp
    format grok
  ]
  CONFIG = BASE_CONFIG + %[
    bind 127.0.0.1
  ]
  IPv6_CONFIG = BASE_CONFIG + %[
    bind ::1
  ]

  def create_driver(conf)
    Fluent::Test::InputTestDriver.new(Fluent::TcpInput).configure(conf)
  end

  def test_configure
    configs = {'127.0.0.1' => CONFIG}
    configs.merge!('::1' => IPv6_CONFIG) if ipv6_enabled?

    configs.each_pair { |k, v|
      d = create_driver(v)
      assert_equal PORT, d.instance.port
      assert_equal k, d.instance.bind
      assert_equal "\n", d.instance.delimiter
    }
  end

  def test_grok_pattern
    tests = [
      {'msg' => "tcptest1\n", 'expected' => 'tcptest1'},
      {'msg' => "tcptest2\n", 'expected' => 'tcptest2'},
    ]
    block_config = %[
      <grok>
        pattern %{GREEDYDATA:message}
      </grok>
    ]

    internal_test_grok('grok_pattern %{GREEDYDATA:message}', tests)
    internal_test_grok(block_config, tests)
  end

  def test_grok_multi_patterns
    tests = [
      {'msg' => "Current time is 2014-01-01T00:00:00+0900\n", 'expected' => '2014-01-01T00:00:00+0900'},
      {'msg' => "The first word matches\n", 'expected' => 'The'}
    ]
    block_config = %[
      <grok>
        pattern %{TIMESTAMP_ISO8601:message}
      </grok>
      <grok>
        pattern %{WORD:message}
      </grok>
    ]
    internal_test_grok(block_config, tests)
  end

  def internal_test_grok(conf, tests)
    d = create_driver(BASE_CONFIG + conf)
    d.run do
      tests.each {|test|
        TCPSocket.open('127.0.0.1', PORT) do |s|
          s.send(test['msg'], 0)
        end
      }
      sleep 1
    end

    compare_test_result(d.emits, tests)
  end

  def compare_test_result(emits, tests)
    assert_equal(2, emits.size)
    emits.each_index {|i|
      assert_equal(tests[i]['expected'], emits[i][2]['message'])
    }
  end
end
