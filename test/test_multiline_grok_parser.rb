require "helper"
require "fluent/plugin/parser_multiline_grok"
require "fluent/config/parser"

require "stringio"

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
    d = create_driver(conf)

    d.instance.parse(text) do |_time, record|
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
    d = create_driver(conf)

    expected = {
      "hostname" => "host1",
      "message1" => "message1",
      "message2" => "message2",
      "message3" => "message3"
    }
    d.instance.parse(text) do |_time, record|
      assert_equal(expected, record)
    end
  end

  def test_empty_range_text_in_text
    text = " [b-a]"
    conf = %[
      grok_pattern %{HOSTNAME:hostname} %{GREEDYDATA:message}
      multiline_start_regexp /^\s/
    ]
    d = create_driver(conf)

    assert(d.instance.firstline?(text))
  end

  class NoGrokPatternMatched < self
    def test_with_grok_failure_key
      config = %[
        grok_failure_key grok_failure
        <grok>
          pattern %{PATH:path}
        </grok>
      ]
      expected = {
        "grok_failure" => "No grok pattern matched",
        "message" => "no such pattern\nno such pattern\n"
      }
      d = create_driver(config)
      d.instance.parse("no such pattern\nno such pattern\n") do |_time, record|
        assert_equal(expected, record)
      end
    end

    def test_without_grok_failure_key
      config = %[
        <grok>
          pattern %{PATH:path}
        </grok>
      ]
      expected = {
        "message" => "no such pattern\nno such pattern\n"
      }
      d = create_driver(config)
      d.instance.parse("no such pattern\nno such pattern\n") do |_time, record|
        assert_equal(expected, record)
      end
    end
  end

  def test_no_grok_patterns
    assert_raise Fluent::ConfigError do
      create_driver('')
    end
  end

  private

  def create_driver(conf)
    Fluent::Test::Driver::Parser.new(Fluent::Plugin::MultilineGrokParser).configure(conf)
  end
end
