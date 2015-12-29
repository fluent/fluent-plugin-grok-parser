require 'fluent/test'
require 'fluent/parser'
require 'fluent/plugin/parser_grok'
require 'tempfile'


include Fluent

def str2time(str_time, format = nil)
  if format
    Time.strptime(str_time, format).to_i
  else
    Time.parse(str_time).to_i
  end
end

class GrokParserTest < ::Test::Unit::TestCase
  def test_call_for_timestamp
    internal_test_grok_pattern('%{TIMESTAMP_ISO8601:time}', 'Some stuff at 2014-01-01T00:00:00+0900',
                               str2time('2014-01-01T00:00:00+0900'), {})
    internal_test_grok_pattern('%{DATESTAMP_RFC822:time}', 'Some stuff at Mon Aug 15 2005 15:52:01 UTC',
                               str2time('Mon Aug 15 2005 15:52:01 UTC'), {})
    internal_test_grok_pattern('%{DATESTAMP_RFC2822:time}', 'Some stuff at Mon, 15 Aug 2005 15:52:01 +0000',
                               str2time('Mon, 15 Aug 2005 15:52:01 +0000'), {})
    internal_test_grok_pattern('%{SYSLOGTIMESTAMP:time}', 'Some stuff at Aug 01 00:00:00',
                               str2time('Aug 01 00:00:00'), {})
  end

  def test_call_for_grok_pattern_not_found
    assert_raise Grok::GrokPatternNotFoundError do
      internal_test_grok_pattern('%{THIS_PATTERN_DOESNT_EXIST}', 'Some stuff at somewhere', nil, {})
    end
  end

  def test_call_for_multiple_fields
    internal_test_grok_pattern('%{MAC:mac_address} %{IP:ip_address}', 'this.wont.match DEAD.BEEF.1234 127.0.0.1', nil,
                               {"mac_address" => "DEAD.BEEF.1234", "ip_address" => "127.0.0.1"})
  end

  def test_call_for_complex_pattern
    internal_test_grok_pattern('%{COMBINEDAPACHELOG}', '127.0.0.1 192.168.0.1 - [28/Feb/2013:12:00:00 +0900] "GET / HTTP/1.1" 200 777 "-" "Opera/12.0"',
                                str2time('28/Feb/2013:12:00:00 +0900', '%d/%b/%Y:%H:%M:%S %z'),
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
                                "time_format" => "%d/%b/%Y:%H:%M:%S %z"
                              )
  end

  def test_call_for_custom_pattern
    pattern_file = File.new(File.expand_path("../my_pattern", __FILE__), "w")
    pattern_file.write("MY_AWESOME_PATTERN %{GREEDYDATA:message}\n")
    pattern_file.close
    begin
      internal_test_grok_pattern('%{MY_AWESOME_PATTERN:message}', 'this is awesome',
                                 nil, {"message" => "this is awesome"},
                                 "custom_pattern_path" => pattern_file.path
                                )
    ensure
      File.delete(pattern_file.path)
    end
  end

  def test_optional_type
    internal_test_grok_pattern('%{INT:user_id:integer} paid %{NUMBER:paid_amount:float}',
                               '12345 paid 6789.10', nil,
                               {"user_id" => 12345, "paid_amount" => 6789.1 })
  end

  private

  def internal_test_grok_pattern(grok_pattern, text, expected_time, expected_record, options = {})
    parser = Fluent::Test::ParserTestDriver.new(TextParser::GrokParser).configure({"grok_pattern" => grok_pattern}.merge(options))

    # for the old, return based API
    time, record = parser.parse(text)
    assert_equal(expected_time, time) if expected_time
    assert_equal(expected_record, record)

    # for the new API
    parser.parse(text) {|time, record|
      assert_equal(expected_time, time) if expected_time
      assert_equal(expected_record, record)
    }
  end
end
