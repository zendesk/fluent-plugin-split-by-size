# fluent-plugin-split-by-size

[Fluentd](https://fluentd.org/) filter plugin to split events based on a max size.

Splits event into multiple events based on a max size using a field id in the original message as an id to associate parts of the original event. This is mostly designed for use with kinesis to allow larger records to be used than 1mb by splitting the records going into kinesis and then re-joining them later.

## Installation

### RubyGems

```
$ gem install fluent-plugin-split-by-size
```

### Bundler

Add following line to your Gemfile:

```ruby
gem "fluent-plugin-split-by-size"
```

And then execute:

```
$ bundle
```

## Configuration

### max_event_size (integer) (optional)

Max size an event can be in bytes

Default value: `1048576`.

### id_field (string) (required)

Field that contains a unique id that will be added to all created events

## Copyright

* Copyright(c) 2018- Timothy Schroeder
* License
  * Apache License, Version 2.0
