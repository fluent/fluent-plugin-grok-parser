# Grok Parser for Fluentd

![Testing on Ubuntu](https://github.com/fluent/fluent-plugin-grok-parser/workflows/Testing%20on%20Ubuntu/badge.svg?branch=master)
![Testing on macOS](https://github.com/fluent/fluent-plugin-grok-parser/workflows/Testing%20on%20macOS/badge.svg?branch=master)

This is a Fluentd plugin to enable Logstash's Grok-like parsing logic.

## Requirements

| fluent-plugin-grok-parser | fluentd    | ruby   |
|---------------------------|------------|--------|
| >= 2.0.0                  | >= v0.14.0 | >= 2.1 |
| < 2.0.0                   | >= v0.12.0 | >= 1.9 |


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

**If you want to try multiple grok patterns and use the first matched one**, you can use the following syntax:

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type grok
    <grok>
      pattern %{HTTPD_COMBINEDLOG}
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

Fluentd accumulates data in the buffer forever to parse complete data when no pattern matches.

You can use this parser without `multiline_start_regexp` when you know your data structure perfectly.

## Configurations

* See also: [Config: Parse Section - Fluentd](https://docs.fluentd.org/configuration/parse-section)

* **time_format** (string) (optional): The format of the time field.
* **grok_pattern** (string) (optional): The pattern of grok. You cannot specify multiple grok pattern with this.
* **custom_pattern_path** (string) (optional): Path to the file that includes custom grok patterns
* **grok_failure_key** (string) (optional): The key has grok failure reason.
* **grok_name_key** (string) (optional): The key name to store grok section's name
* **multi_line_start_regexp** (string) (optional): The regexp to match beginning of multiline. This is only for "multiline_grok".
* **grok_pattern_series** (enum) (optional): Specify grok pattern series set.
  * Default value: `legacy`.

### \<grok\> section (optional) (multiple)

* **name** (string) (optional): The name of this grok section
* **pattern** (string) (required): The pattern of grok
* **keep_time_key** (bool) (optional): If true, keep time field in the record.
* **time_key** (string) (optional): Specify time field for event time. If the event doesn't have this field, current time is used.
  * Default value: `time`.
* **time_format** (string) (optional): Process value using specified format. This is available only when time_type is string
* **timezone** (string) (optional): Use specified timezone. one can parse/format the time value in the specified timezone.


## Examples

### Using grok\_failure\_key

```aconf
<source>
  @type dummy
  @label @dummy
  dummy [
    { "message1": "no grok pattern matched!", "prog": "foo" },
    { "message1": "/", "prog": "bar" }
  ]
  tag dummy.log
</source>

<label @dummy>
  <filter>
    @type parser
    key_name message1
    reserve_data true
    reserve_time true
    <parse>
      @type grok
      grok_failure_key grokfailure
      <grok>
        pattern %{PATH:path}
      </grok>
    </parse>
  </filter>
  <match dummy.log>
    @type stdout
  </match>
</label>
```

This generates following events:

```
2016-11-28 13:07:08.009131727 +0900 dummy.log: {"message1":"no grok pattern matched!","prog":"foo","message":"no grok pattern matched!","grokfailure":"No grok pattern matched"}
2016-11-28 13:07:09.010400923 +0900 dummy.log: {"message1":"/","prog":"bar","path":"/"}
```

### Using grok\_name\_key

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type grok
    grok_name_key grok_name
    grok_failure_key grokfailure
    <grok>
      name apache_log
      pattern %{HTTPD_COMBINEDLOG}
      time_format "%d/%b/%Y:%H:%M:%S %z"
    </grok>
    <grok>
      name ip_address
      pattern %{IP:ip_address}
    </grok>
    <grok>
      name rest_message
      pattern %{GREEDYDATA:message}
    </grok>
  </parse>
</source>
```

This will add keys like following:

* Add `grok_name: "apache_log"` if the record matches `HTTPD_COMBINEDLOG`
* Add `grok_name: "ip_address"` if the record matches `IP`
* Add `grok_name: "rest_message"` if the record matches `GREEDYDATA`

Add `grokfailure` key to the record if the record does not match any grok pattern.
See also test code for more details.

## How to parse time value using specific timezone

```aconf
<source>
  @type tail
  path /path/to/log
  tag grokked_log
  <parse>
    @type grok
    <grok>
      name mylog-without-timezone
      pattern %{DATESTAMP:time} %{GREEDYDATE:message}
      timezone Asia/Tokyo
    </grok>
  </parse>
</source>
```

This will parse the `time` value as "Asia/Tokyo" timezone.

See [Config: Parse Section - Fluentd](https://docs.fluentd.org/configuration/parse-section) for more details about timezone.

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

```aconf
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

## Notice

If you want to use this plugin with Fluentd v0.12.x or earlier, you can use this plugin version v1.x.

See also: [Plugin Management | Fluentd](https://docs.fluentd.org/deployment/plugin-management)

## License

Apache 2.0 License
