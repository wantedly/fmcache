# FMCache

[![Build Status](https://travis-ci.org/wantedly/fmcache.svg?branch=master)](https://travis-ci.org/wantedly/fmcache)
[![Gem Version](https://badge.fury.io/rb/fmcache.svg)](https://badge.fury.io/rb/fmcache)

Library for caching json masked by FieldMask

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'fmcache'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install fmcache

## Usage

You can get data from the cache by using `FMCache::Engine#fetch`. If there is uncached data, you can pass the block and fetch the rest from the other data source.

An example of code is shown below.

```ruby
[4] pry(main)> redis = Redis.new(url: "redis://localhost:6379")
=> #<Redis client v4.0.3 for redis://localhost:6379>

[5] pry(main)> cache_engine = FMCache::Engine.new(client: redis, fm_parser: -> (fields) { FieldMaskParser.parse(paths: fields, root: User) })
=> #<FMCache::Engine:0x00007fb5f8f985e8
 @client=#<FMCache::Client:0x00007fb5f8f98598 @client=#<Redis client v4.0.3 for redis://localhost:6379>, @notifier=nil>,
 @decoder=
  #<FMCache::Decoder:0x00007fb5f8f984d0
   @field_mask_parser=#<Proc:XXX (lambda)>,
   @fields_checker=#<FMCache::Decoder::FieldsChecker:0x00007fb5f8f98458>,
   @value_decoder=#<FMCache::Decoder::ValueDecoder:0x00007fb5f8f98480>>,
 @encoder=#<FMCache::Encoder:0x00007fb5f8f984f8>,
 @fm_parser=#<Proc:XXX (lambda)>,
 @ttl=604800>

[7] pry(main)> cache_engine.fetch(ids: [1], field_mask: FieldMaskParser.parse(paths: ["id", "name"], root: User)) do |ids, field_mask|
[7] pry(main)*   fetch_json(ids, field_mask)
[7] pry(main)* end
=> [{:id=>1, :name=>"Taro"}]
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake true` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/wantedly/fmcache.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).
