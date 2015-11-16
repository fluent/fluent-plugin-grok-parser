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
  private

  def create_parser(conf)
    parser = TextParser::MultilineGrokParser.new
    io = StringIO.new(conf)
    parser.configure(Config::Parser.parse(io, "fluent.conf"))
    parser
  end
end
