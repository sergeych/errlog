# Errlog

The Errlog logging client (http://errorlog.co). with rails & delayed_job integrations. See usage details
at http://errorlog.co/help/rails. The service is in beta test now.


## Installation

Add this line to your application's Gemfile:

    gem 'errlog'

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install errlog

More: http://errorlog.co/help/rails

## Usage

    Errlog.configure(...) # visit the link above for help on credentials

    Errlog.protect { |ctx|
        # Any exception from here will be caught and reported
        ctx.extra_data = "Anything you want to attach to trace/warning/error report"
    }

    Errlog.protect_rethrow { |ctx|
        # Same as above, but the exception will be rethrown
    }

    Errlog.trace "So far so good"

    # some syntax sugar

    x == y or Errlog.error "Something is wrong" do |ctx|
        ctx.expected_value = x
        ctx.real_one = y
    }

    begin
        ...
    rescue Exception => e
        Errlog.context.exception e
        ...
    end

    logger = Errlog::ChainLogger.new
    logger.info "This string will be collected"


Consult API docs for more: http://rdoc.info/github/sergeych/errlog/master/frames. Configuration
details are available at http://errorlog.co/help/rails

As the service is under active development, be sure to `bundle update errlog` regularly.

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request
