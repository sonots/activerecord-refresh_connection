# activerecord-refresh_connection


[![Build Status](https://secure.travis-ci.org/sonots/activerecord-refresh_connection.png?branch=master)](http://travis-ci.org/sonots/activerecord-refresh_connection)
[![Coverage Status](https://coveralls.io/repos/sonots/activerecord-refresh_connection/badge.png?branch=master)](https://coveralls.io/r/sonots/activerecord-refresh_connection?branch=master)

Refresh ActiveRecord connection on each rack request 

## Installation

Add the following to your `Gemfile`:

```ruby
gem 'activerecord-refresh_connection'
```

And then execute:

```plain
$ bundle
```

## How to Use

This gem provides a rack middleware `ActiveRecord::ConnectionAdapters::RefreshConnectionManagement` which disconnects all connections in each rack request. 

### Rails

Swap the default rails ConnectionManagement.

```ruby
# config/application.rb
require 'activerecord-refresh_connection'

class Application < Rails::Application
  config.autoload_paths += %W(#{config.root}/lib)
  config.middleware.swap ActiveRecord::ConnectionAdapters::ConnectionManagement,
    "ActiveRecord::ConnectionAdapters::RefreshConnectionManagement"
end
```

Middleware check. 

```bash
bundle exec rake middleware
```

### Sinatra

To Be Written

## ChangeLog

See [CHANGELOG.md](CHANGELOG.md) for details.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new [Pull Request](../../pull/new/master)

## Copyright

Copyright (c) 2014 Naotoshi Seo. See [LICENSE.txt](LICENSE.txt) for details.
