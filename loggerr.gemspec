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

  gem.add_development_dependency "rspec"
end
