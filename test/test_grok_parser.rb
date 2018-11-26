require "helper"
require "tempfile"
require "fluent/plugin/parser_grok"

def str2time(str_time, format = nil)
  if format
    Time.strptime(str_time, format).to_i
  else
    Time.parse(str_time).to_i
  end
end

class GrokParserTest < ::Test::Unit::TestCase
  setup do
    Fluent::Test.setup
  end

  sub_test_case "timestamp" do
    test "timestamp iso8601" do
      internal_test_grok_pattern("%{TIMESTAMP_ISO8601:time}", "Some stuff at 2014-01-01T00:00:00+0900",
                                 event_time("2014-01-01T00:00:00+0900"), {})
    end

    test "datestamp rfc822 with zone" do
      internal_test_grok_pattern("%{DATESTAMP_RFC822:time}", "Some stuff at Mon Aug 15 2005 15:52:01 UTC",
                                 event_time("Mon Aug 15 2005 15:52:01 UTC"), {})
    end

    test "datestamp rfc822 with numeric zone" do
      internal_test_grok_pattern("%{DATESTAMP_RFC2822:time}", "Some stuff at Mon, 15 Aug 2005 15:52:01 +0000",
                                 event_time("Mon, 15 Aug 2005 15:52:01 +0000"), {})
    end

    test "syslogtimestamp" do
      internal_test_grok_pattern("%{SYSLOGTIMESTAMP:time}", "Some stuff at Aug 01 00:00:00",
                                 event_time("Aug 01 00:00:00"), {})
    end
  end

  test "date" do
    internal_test_grok_pattern("\\[(?<date>%{DATE} %{TIME} (?:AM|PM))\\]", "[2/16/2018 10:19:34 AM]",
                               nil, { "date" => "2/16/2018 10:19:34 AM" })
  end

  test "grok pattern not found" do
    assert_raise Fluent::Grok::GrokPatternNotFoundError do
      internal_test_grok_pattern("%{THIS_PATTERN_DOESNT_EXIST}", "Some stuff at somewhere", nil, {})
    end
  end

  test "multiple fields" do
    internal_test_grok_pattern("%{MAC:mac_address} %{IP:ip_address}", "this.wont.match DEAD.BEEF.1234 127.0.0.1", nil,
                               {"mac_address" => "DEAD.BEEF.1234", "ip_address" => "127.0.0.1"})
  end

  test "complex pattern" do
    internal_test_grok_pattern("%{COMBINEDAPACHELOG}", '127.0.0.1 192.168.0.1 - [28/Feb/2013:12:00:00 +0900] "GET / HTTP/1.1" 200 777 "-" "Opera/12.0"',
                                str2time("28/Feb/2013:12:00:00 +0900", "%d/%b/%Y:%H:%M:%S %z"),
                                {
                                  "clientip"    => "127.0.0.1",
                                  "ident"       => "192.168.0.1",
                                  "auth"        => "-",
                                  "verb"        => "GET",
                                  "request"     => "/",
                                  "httpversion" => "1.1",
                                  "response"    => "200",
                                  "bytes"       => "777",
                                  "referrer"    => "\"-\"",
                                  "agent"       => "\"Opera/12.0\""
                                },
                                "time_key" => "timestamp",
                                "time_format" => "%d/%b/%Y:%H:%M:%S %z"
                              )
  end

  test "custom pattern" do
    internal_test_grok_pattern("%{MY_AWESOME_PATTERN:message}", "this is awesome",
                               nil, {"message" => "this is awesome"},
                               "custom_pattern_path" => fixtures("my_pattern").to_s)
  end

  sub_test_case "OptionalType" do
    test "simple" do
      internal_test_grok_pattern("%{INT:user_id:integer} paid %{NUMBER:paid_amount:float}",
                                 "12345 paid 6789.10", nil,
                                 {"user_id" => 12345, "paid_amount" => 6789.1 })
    end

    test "array" do
      internal_test_grok_pattern("%{GREEDYDATA:message:array}",
                                 "a,b,c,d", nil,
                                 {"message" => %w(a b c d)})
    end

    test "array with delimiter" do
      internal_test_grok_pattern("%{GREEDYDATA:message:array:|}",
                                 "a|b|c|d", nil,
                                 {"message" => %w(a b c d)})
    end

    test "timestamp iso8601" do
      internal_test_grok_pattern("%{TIMESTAMP_ISO8601:stamp:time}", "Some stuff at 2014-01-01T00:00:00+0900",
                                 nil, {"stamp" => event_time("2014-01-01T00:00:00+0900")})
    end

    test "datestamp rfc822 with zone" do
      internal_test_grok_pattern("%{DATESTAMP_RFC822:stamp:time}", "Some stuff at Mon Aug 15 2005 15:52:01 UTC",
                                 nil, {"stamp" => event_time("Mon Aug 15 2005 15:52:01 UTC")})
    end

    test "datestamp rfc822 with numeric zone" do
      internal_test_grok_pattern("%{DATESTAMP_RFC2822:stamp:time}", "Some stuff at Mon, 15 Aug 2005 15:52:01 +0000",
                                 nil, {"stamp" => event_time("Mon, 15 Aug 2005 15:52:01 +0000")})
    end

    test "syslogtimestamp" do
      internal_test_grok_pattern("%{SYSLOGTIMESTAMP:stamp:time}", "Some stuff at Aug 01 00:00:00",
                                 nil, {"stamp" => event_time("Aug 01 00:00:00")})
    end

    test "timestamp with format" do
      internal_test_grok_pattern("%{TIMESTAMP_ISO8601:stamp:time:%Y-%m-%d %H%M}", "Some stuff at 2014-01-01 1000",
                                 nil, {"stamp" => event_time("2014-01-01 10:00")})
    end
  end

  sub_test_case "NoGrokPatternMatched" do
    test "with grok_failure_key" do
      config = %[
        grok_failure_key grok_failure
        <grok>
          pattern %{PATH:path}
        </grok>
      ]
      expected = {
        "grok_failure" => "No grok pattern matched",
        "message" => "no such pattern"
      }
      d = create_driver(config)
      d.instance.parse("no such pattern") do |_time, record|
        assert_equal(expected, record)
      end
    end

    test "without grok_failure_key" do
      config = %[
        <grok>
          pattern %{PATH:path}
        </grok>
      ]
      expected = {
        "message" => "no such pattern"
      }
      d = create_driver(config)
      d.instance.parse("no such pattern") do |_time, record|
        assert_equal(expected, record)
      end
    end
  end

  test "no grok patterns" do
    assert_raise Fluent::ConfigError do
      create_driver('')
    end
  end

  test "invalid config value type" do
    assert_raise Fluent::ConfigError do
      create_driver(%[
        <grok>
          pattern %{PATH:path:foo}
        </grok>
      ])
    end
  end

  test "invalid config value type and normal grok pattern" do
    d = create_driver(%[
      <grok>
        pattern %{PATH:path:foo}
      </grok>
      <grok>
        pattern %{IP:ip_address}
      </grok>
    ])
    assert_equal(1, d.instance.instance_variable_get(:@grok).parsers.size)
    logs = $log.instance_variable_get(:@logger).instance_variable_get(:@logdev).logs
    error_logs = logs.grep(/error_class/)
    assert_equal(1, error_logs.size)
    error_message = error_logs.first[/error="(.+)"/, 1]
    assert_equal("unknown value conversion for key:'path', type:'foo'", error_message)
  end

  sub_test_case "grok_name_key" do
    test "one grok section with name" do
      d = create_driver(%[
        grok_name_key grok_name
        <grok>
          name path
          pattern %{PATH:path}
        </grok>
      ])
      expected = {
        "path" => "/",
        "grok_name" => "path"
      }
      d.instance.parse("/") do |time, record|
        assert_equal(expected, record)
      end
    end

    test "one grok section without name" do
      d = create_driver(%[
        grok_name_key grok_name
        <grok>
          pattern %{PATH:path}
        </grok>
      ])
      expected = {
        "path" => "/",
        "grok_name" => 0
      }
      d.instance.parse("/") do |time, record|
        assert_equal(expected, record)
      end
    end

    test "multiple grok sections with name" do
      d = create_driver(%[
        grok_name_key grok_name
        <grok>
          name path
          pattern %{PATH:path}
        </grok>
        <grok>
          name ip
          pattern %{IP:ip_address}
        </grok>
      ])
      expected = [
        { "path" => "/", "grok_name" => "path" },
        { "ip_address" => "127.0.0.1", "grok_name" => "ip" },
      ]
      records = []
      d.instance.parse("/") do |time, record|
        records << record
      end
      d.instance.parse("127.0.0.1") do |time, record|
        records << record
      end
      assert_equal(expected, records)
    end

    test "multiple grok sections without name" do
      d = create_driver(%[
        grok_name_key grok_name
        <grok>
          pattern %{PATH:path}
        </grok>
        <grok>
          pattern %{IP:ip_address}
        </grok>
      ])
      expected = [
        { "path" => "/", "grok_name" => 0 },
        { "ip_address" => "127.0.0.1", "grok_name" => 1 },
      ]
      records = []
      d.instance.parse("/") do |time, record|
        records << record
      end
      d.instance.parse("127.0.0.1") do |time, record|
        records << record
      end
      assert_equal(expected, records)
    end

    test "multiple grok sections with both name and index" do
      d = create_driver(%[
        grok_name_key grok_name
        <grok>
          name path
          pattern %{PATH:path}
        </grok>
        <grok>
          pattern %{IP:ip_address}
        </grok>
      ])
      expected = [
        { "path" => "/", "grok_name" => "path" },
        { "ip_address" => "127.0.0.1", "grok_name" => 1 },
      ]
      records = []
      d.instance.parse("/") do |time, record|
        records << record
      end
      d.instance.parse("127.0.0.1") do |time, record|
        records << record
      end
      assert_equal(expected, records)
    end
  end

  sub_test_case "keep_time_key" do
    test "true" do
      d = create_driver(%[
        keep_time_key true
        <grok>
          pattern "%{TIMESTAMP_ISO8601:time}"
        </grok>
      ])
      expected = [
        { "time" => "2014-01-01T00:00:00+0900" }
      ]
      records = []
      d.instance.parse("Some stuff at 2014-01-01T00:00:00+0900") do |time, record|
        assert_equal(event_time("2014-01-01T00:00:00+0900"), time)
        records << record
      end
      assert_equal(expected, records)
    end
  end

  sub_test_case "grok section" do
    test "complex pattern" do
      d = create_driver(%[
        <grok>
          pattern %{COMBINEDAPACHELOG}
          time_key timestamp
          time_format %d/%b/%Y:%H:%M:%S %z
        </grok>
      ])
      expected_record = {
        "clientip"    => "127.0.0.1",
        "ident"       => "192.168.0.1",
        "auth"        => "-",
        "verb"        => "GET",
        "request"     => "/",
        "httpversion" => "1.1",
        "response"    => "200",
        "bytes"       => "777",
        "referrer"    => "\"-\"",
        "agent"       => "\"Opera/12.0\""
      }
      d.instance.parse('127.0.0.1 192.168.0.1 - [28/Feb/2013:12:00:00 +0900] "GET / HTTP/1.1" 200 777 "-" "Opera/12.0"') do |time, record|
        assert_equal(expected_record, record)
        assert_equal(event_time("28/Feb/2013:12:00:00 +0900", format: "%d/%b/%Y:%H:%M:%S %z"), time)
      end
    end
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Parser.new(Fluent::Plugin::GrokParser).configure(conf)
  end

  def internal_test_grok_pattern(grok_pattern, text, expected_time, expected_record, options = {})
    d = create_driver({"grok_pattern" => grok_pattern}.merge(options))

    # for the new API
    d.instance.parse(text) {|time, record|
      assert_equal(expected_time, time) if expected_time
      assert_equal(expected_record, record)
    }
  end
end
