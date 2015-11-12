require 'fluent/plugin/parser_multiline_grok'

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
    parser = TextParser::MultilineGrokParser.new
    options = {
      "grok_pattern" => '%{HOSTNAME:hostname} %{GREEDYDATA:message}',
      "multiline_start_regexp" => '/^\s/'
    }
    parser.configure(Config::Element.new('ROOT', '', options, []))

    parser.parse(text) do |time, record|
      assert_equal({ "hostname" => "host1", "message" => message }, record)
    end
  end
end
