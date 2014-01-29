# Derailer

Derailer is a static analysis tool for Rails applications. It
produces a graph showing the conditions under which your application
allows data to flow from the database to rendered web pages seen by
users. The goal is for this graph to aid the user in discovering
unintended data flows that may represent security bugs.

## Installation

Add these lines to your application's Gemfile:

    gem 'sourcify', :git => "git://github.com/jnear/sourcify.git"
    gem 'virtual_keywords', :git => "git://github.com/jnear/virtual_keywords.git"
    gem 'derailer', :git => "git://github.com/jnear/derailer.git"

And then execute:

    $ bundle install

## Usage

To run the analysis, execute:

    $ bundle exec rake derailer

Once it's finished, it will start a webserver. To see the analysis
results, browse to:

    http://localhost:8000

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
