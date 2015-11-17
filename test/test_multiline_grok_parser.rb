require 'fluent/plugin/parser_multiline_grok'
require 'fluent/config/parser'

require 'stringio'

class MultilineGrokParserTest < Test::Unit::TestCase
  def test_multiline
    text=<<TEXT.chomp
host1 message1
 message2
 message3
TEXT
    message =<<MESSAGE.chomp
message1
 message2
 message3
MESSAGE
    conf = %[
      grok_pattern %{HOSTNAME:hostname} %{GREEDYDATA:message}
      multiline_start_regexp /^\s/
    ]
    parser = create_parser(conf)

    parser.parse(text) do |time, record|
      assert_equal({ "hostname" => "host1", "message" => message }, record)
    end
  end

  def test_without_multiline_start_regexp
    text = <<TEXT.chomp
host1 message1
 message2
 message3
end
TEXT
    conf = %[
       grok_pattern %{HOSTNAME:hostname} %{DATA:message1}\\n %{DATA:message2}\\n %{DATA:message3}\\nend
    ]
    parser = create_parser(conf)

    expected = {
      "hostname" => "host1",
      "message1" => "message1",
      "message2" => "message2",
      "message3" => "message3"
    }
    parser.parse(text) do |time, record|
      assert_equal(expected, record)
    end
  end

  private

  def create_parser(conf)
    parser = TextParser::MultilineGrokParser.new
    io = StringIO.new(conf)
    parser.configure(Config::Parser.parse(io, "fluent.conf"))
    parser
  end
end
