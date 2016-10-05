# Grok Parser for Fluentd [![Build Status](https://travis-ci.org/kiyoto/fluent-plugin-grok-parser.svg?branch=master)](https://travis-ci.org/kiyoto/fluent-plugin-grok-parser)

This is a Fluentd plugin to enable Logstash's Grok-like parsing logic.

## What's Grok?

Grok is a macro to simplify and reuse regexes, originally developed by [Jordan Sissel](http://github.com/jordansissel).

This is a partial implementation of Grok's grammer that should meet most of the needs.

## How It Works

You can use it wherever you used the `format` parameter to parse texts. In the following example, it
extracts the first IP address that matches in the log.

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type grok
    grok_pattern %{IP:ip_address}
  </parse>
</source>
```

You can also use Fluentd v0.12 style:

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  format grok
  grok_pattern %{IP:ip_address}
</source>
```

**If you want to try multiple grok patterns and use the first matched one**, you can use the following syntax:

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type grok
    <grok>
      pattern %{COMBINEDAPACHELOG}
      time_format "%d/%b/%Y:%H:%M:%S %z"
    </grok>
    <grok>
      pattern %{IP:ip_address}
    </grok>
    <grok>
      pattern %{GREEDYDATA:message}
    </grok>
  </parse>
</source>
```

You can also use Fluentd v0.12 style:

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  format grok
  <grok>
    pattern %{COMBINEDAPACHELOG}
    time_format "%d/%b/%Y:%H:%M:%S %z"
  </grok>
  <grok>
    pattern %{IP:ip_address}
  </grok>
  <grok>
    pattern %{GREEDYDATA:message}
  </grok>
</source>
```

### Multiline support

You can parse multiple line text.

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type multiline_grok
    grok_pattern %{IP:ip_address}%{GREEDYDATA:message}
    multiline_start_regexp /^[^\s]/
  </parse>
</source>
```

You can also use Fluentd v0.12 style:

```aconf
<source>
  @type tail
  path /path/to/log
  format multiline_grok
  grok_pattern %{IP:ip_address}%{GREEDYDATA:message}
  multiline_start_regexp /^[^\s]/
  tag grokked_log
</source>
```

You can use multiple grok patterns to parse your data.

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type multiline_grok
    <grok>
      pattern Started %{WORD:verb} "%{URIPATH:pathinfo}" for %{IP:ip} at %{TIMESTAMP_ISO8601:timestamp}\nProcessing by %{WORD:controller}#%{WORD:action} as %{WORD:format}%{DATA:message}Completed %{NUMBER:response} %{WORD} in %{NUMBER:elapsed} (%{DATA:elapsed_details})
    </grok>
  </parse>
</source>
```

You can also use Fluentd v0.12 style:

```aconf
<source>
  @type tail
  path /path/to/log
  format multiline_grok
  <grok>
    pattern Started %{WORD:verb} "%{URIPATH:pathinfo}" for %{IP:ip} at %{TIMESTAMP_ISO8601:timestamp}\nProcessing by %{WORD:controller}#%{WORD:action} as %{WORD:format}%{DATA:message}Completed %{NUMBER:response} %{WORD} in %{NUMBER:elapsed} (%{DATA:elapsed_details})
  </grok>
  tag grokked_log
</source>
```

Fluentd accumulates data in the buffer forever to parse complete data when no pattern matches.

You can use this parser without `multiline_start_regexp` when you know your data structure perfectly.

## How to write Grok patterns

Grok patterns look like `%{PATTERN_NAME:name}` where ":name" is optional. If "name" is provided, then it
becomes a named capture. So, for example, if you have the grok pattern

```
%{IP} %{HOST:host}
```

it matches

```
127.0.0.1 foo.example
```

but only extracts "foo.example" as {"host": "foo.example"}

Please see `patterns/*` for the patterns that are supported out of the box.

## How to add your own Grok pattern

You can add your own Grok patterns by creating your own Grok file and telling the plugin to read it.
This is what the `custom_pattern_path` parameter is for.

```
<source>
  @type tail
  path /path/to/log
  <parse>
    @type grok
    grok_pattern %{MY_SUPER_PATTERN}
    custom_pattern_path /path/to/my_pattern
  </parse>
</source>
```

`custom_pattern_path` can be either a directory or file. If it's a directory, it reads all the files in it.

## FAQs

### 1. How can I convert types of the matched patterns like Logstash's Grok?

Although every parsed field has type `string` by default, you can specify other types. This is useful when filtering particular fields numerically or storing data with sensible type information.

The syntax is

```
grok_pattern %{GROK_PATTERN:NAME:TYPE}...
```

e.g.,

```
grok_pattern %{INT:foo:integer}
```

Unspecified fields are parsed at the default string type.

The list of supported types are shown below:

* `string`
* `bool`
* `integer` ("int" would NOT work!)
* `float`
* `time`
* `array`

For the `time` and `array` types, there is an optional 4th field after the type name. For the "time" type, you can specify a time format like you would in `time_format`.

For the "array" type, the third field specifies the delimiter (the default is ","). For example, if a field called "item\_ids" contains the value "3,4,5", `types item_ids:array` parses it as ["3", "4", "5"]. Alternatively, if the value is "Adam|Alice|Bob", `types item_ids:array:|` parses it as ["Adam", "Alice", "Bob"].

Here is a sample config using the Grok parser with `in_tail` and the `types` parameter:

```aconf
<source>
  @type tail
  path /path/to/log
  format grok
  grok_pattern %{INT:user_id:integer} paid %{NUMBER:paid_amount:float}
  tag payment
</source>
```

## License

Apache 2.0 License
