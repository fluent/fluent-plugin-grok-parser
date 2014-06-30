# Grok Parser for Fluentd

This is a Fluentd plugin to enable Logstash's Grok-like parsing logic.

## What's Grok?

Grok is a macro to simplify and reuse regexes, originally developed by [Jordan Sissel](http://github.com/semicomplete).

This is a partial implementation of Grok's grammer that should meet most of the needs.

## How It Works

You can use it wherever you used the `format` parameter to parse texts. In the following example, it
extracts the first IP address that matches in the log.

```
<source>
  type tail
  path /path/to/log
  format grok
  grok_pattern %{IP:ip_address}
</source>
```

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
  type tail
  path /path/to/log
  format grok
  grok_pattern %{MY_SUPER_PATTERN}
  custom_pattern_path /path/to/my_pattern
</source>
```

`custom_pattern_path` can be either a directory or file. If it's a directory, it reads all the files in it.

## License

Apache 2.0 License
