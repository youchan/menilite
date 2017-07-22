# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'menilite/version'

Gem::Specification.new do |spec|
  spec.name          = "menilite"
  spec.version       = Menilite::VERSION
  spec.authors       = ["youchan"]
  spec.email         = ["youchan01@gmail.com"]

  spec.summary       = %q{Isomorphic models between client side opal and server side ruby.}
  spec.description   = %q{This is isomorphic models for sharing between client side and server side.}
  spec.homepage      = "https://github.com/youchan/menilite"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.12"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency 'opal-rspec'

  spec.add_runtime_dependency "opal"
  spec.add_runtime_dependency "sinatra-activerecord"
end
