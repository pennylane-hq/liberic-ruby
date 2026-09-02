# Liberic

Liberic is a ruby wrapper for ERiC, a C library to interact with German
Tax Authority's ELSTER service.

**WARNING:** This gem is at a very early stage and not able to do much useful stuff.

## Documentation

This README can only give a brief overview. You can look up the complete
[documentation on RubyDoc.info](http://www.rubydoc.info/github/mpm/liberic-ruby).

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'liberic'
```

And then execute:

    $ bundle

Or install it yourself (not possible yet) as:

    $ gem install liberic

The ERiC library files are not distributed with this gem. On Linux x86-64,
download and install the SDK and its documentation with:

```sh
bundle exec rake eric:install
```

This installs ERiC `43.5.4.0` by default. To select another full release,
run:

```sh
ERIC_VERSION=43.5.4.0 bundle exec rake eric:install
```

The task derives the ELSTER `eric_<major>` download directory from the version's
first component. It caches completed archives in `.eric/downloads/` and extracts
them below `.eric/`, producing this SDK home for the default version:

```text
.eric/ERiC-43.5.4.0/Linux-x86_64
```

Allow at least 1.5 GB of free disk space for roughly 680 MB of downloads and
their extracted contents. Downloads use temporary `.part` files, can be reused
on later runs, and are not included in the repository or packaged gem. The
installer supports only the official Linux x86-64 SDK.

After installation, set the version-independent `ERIC_HOME` variable in the
shell where Liberic will run:

```sh
export ERIC_HOME="$PWD/.eric/ERiC-43.5.4.0/Linux-x86_64"
```

The install task prints the exact command for the selected version. A Rake
process cannot permanently change the environment of its parent shell, so you
must run the command yourself or add it to your shell configuration.

For a manual or shared installation, obtain ERiC from the
[ELSTER Entwicklerbereich](https://www.elster.de/elsterweb/entwickler/infoseite/eric),
which requires developer credentials. You can also browse the public
[ELSTER developer information](https://www.elster.de/elsterweb/infoseite/entwickler).
Follow the official installation instructions and extract the SDK to a location
of your choice. It should contain at least these folders:

```
bin/
include/
lib/
```

Set `ERIC_HOME` to that folder or the gem will not find the library files.
For compatibility with existing applications, `ERIC_HOME_40` remains a
fallback when `ERIC_HOME` is not set.

For example:

```sh
export ERIC_HOME=/opt/ERiC-43.5.4.0/Linux-x86_64
```

The gem will raise a `Liberic::InitializationError` if neither environment
variable is set.
In a Rails project this can interfere with running rake (for example
when building the app in Docker). In this case, use `gem 'liberic', require: false` in your `Gemfile`.
And require the gem later in your Rails code (for example a model) by
calling `require 'liberic'`.

### Additional steps on OS X

The following OS X specific information dates back to the first version of this
library (from 2016). Might be outdated or incorrect by now.

On *Mac OS X* you need to process the libraries to fix the interal paths
(credits to @deviantbits):

```
libs=`ls $ERIC_HOME/lib/*.dylib`
plugins=`ls $ERIC_HOME/lib/plugins2/*.dylib`

for target in $libs
do
  for lib in $libs
  do
    install_name_tool -change "@rpath/"`basename $lib` "$ERIC_HOME/lib/"`basename $lib` $target
  done

  for plugin in $plugins
  do
    install_name_tool -change "@rpath/plugins2/"`basename $plugin` "$ERIC_HOME/lib/plugins2/"`basename $plugin` $target
  done
done

for target in $plugins
do
  for lib in $libs
  do
    install_name_tool -change "@rpath/"`basename $lib` "$ERIC_HOME/lib/"`basename $lib` $target
  done
done
```

Check your settings by running:

```sh
$ ls $ERIC_HOME/lib/libericapi.*
```
This should list you one file with an operating system dependend suffix.

## Usage

The gem exposes an interface to ERiC's native functions inside the
`Liberic::SDK::API` namespace.

Function names have been converted from camel case and stripped of the
'Eric' prefix, otherwise the original (German) names have been kept.

For example:

```c
EricSystemCheck();
```
is in Ruby:

```ruby
Liberic::SDK::API.system_check
```

A more Ruby friendly encapsulation of the ERiC functionality is in the
making (check out `Liberic::Process`).

## Examples

The following script will load an example tax filing (from the SDK) to
validate it with ERiC.

```ruby
require 'liberic'

# Use a convenience wrapper that deals with creating a buffer for the
# native function's results. This will also raise a Ruby exception if
# the native function returns anything else then 0 (= OK).
version_info = Liberic::Helpers::Invocation.with_result_buffer do |handle|

  # Call ERiC function EricVersion()
  Liberic::SDK::API::version(handle)
end

# version info contains XML with all ERiC libraries and their versions.
puts version_info

# Read example file that declares income tax for 2011. Assumes you have extraced
# the 'Beispiel' folder that comes with the ERiC libraries.
tax_filing = File.read(File.expand_path('Beispiel/ericdemo-java/steuersatz.xml', Liberic.eric_home))

# Liberic::Process is a high level wrapper around ERiC's EricBearbeiteVorgang() function.
submission = Liberic::Process.new(tax_filing, 'ESt_2011')

# Check for validity of the XML schema
submission.check

# Submit tax filing for a dry run (validity of the fields will be checked).
result = submission.execute

# Will be empty if everything was ok. Otherwise, result contains XML with a list of offending fields.
# Try editing the example file to see this in action- for example change the year of birth to a future year, etc.
puts result
```

## Features

This gem is rather early stage. It does not implement all ERiC features
yet. It does support submitting various tax filings via
`Liberic::Process` which should be sufficient for the majority of use
cases. Dealing with certificates (necessary for retrieving the tax
assessment or cryptographically signing a tax filing) is possible, but
no Ruby style wrapper exists yet.

Please refer to `Liberic::SDK::API` and the official docs for this.

## Bugs

This library is used in production for submitting tax filings. Not all
of the methods implemented in `Liberic::SDK::API` have been tested
though, so the data types defined there might be wrong.

Please consider this if you encounter problems and are looking for bugs
in your code.

Pull requests, improvements and examples are welcome, we are all in this
together :)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/mpm/liberic. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](contributor-covenant.org) code of conduct.
