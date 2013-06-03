# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'railgrinder/version'

Gem::Specification.new do |spec|
  spec.name          = "railgrinder"
  spec.version       = Railgrinder::VERSION
  spec.authors       = ["Joseph Near"]
  spec.email         = ["jnear@csail.mit.edu"]
  spec.description   = %q{TODO: Write a gem description}
  spec.summary       = %q{TODO: Write a gem summary}
  spec.homepage      = ""
  spec.license       = "GPLv3"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rake"
  s.add_dependency 'rspec-rails'
  s.add_dependency 'ruby_parser'
  s.add_dependency 'ruby2ruby'
  s.add_dependency 'sourcify'
  s.add_dependency 'virtual_keywords'
end
