# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'loggerr/version'

Gem::Specification.new do |gem|
  gem.name          = "loggerr"
  gem.version       = Loggerr::VERSION
  gem.authors       = ["sergeych"]
  gem.email         = ["real.sergeych@gmail.com"]
  gem.description   = %q{Logger and error reporter agent for loggerr service}
  gem.summary       = %q{under development}
  gem.homepage      = ""

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.bindir        = 'bin'

  gem.required_ruby_version = '>= 1.9.2'

  gem.add_dependency 'boss-protocol', '>= 0.1.3'
  gem.add_dependency 'hashie', '>= 1.2.0'
  gem.add_dependency 'httpclient', '>= 2.3'
  gem.add_dependency 'colorize'
  gem.add_development_dependency "rspec"
end
