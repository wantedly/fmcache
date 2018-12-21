
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "fmcache/version"

Gem::Specification.new do |spec|
  spec.name          = "fmcache"
  spec.version       = FMCache::VERSION
  spec.authors       = ["Nao Minami"]
  spec.email         = ["south37777@gmail.com"]

  spec.summary       = %q{Library for caching json masked by FieldMask}
  spec.description   = %q{Library for caching json masked by FieldMask}
  spec.homepage      = "https://github.com/south37/fmcache"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.8"
  spec.add_development_dependency "pry", "~> 0.11"
  spec.add_development_dependency "mock_redis", "~> 0.19"
  spec.add_development_dependency "redis", "~> 4.0"
  spec.add_development_dependency "activerecord", "~> 5.2"
  spec.add_dependency "field_mask_parser", "~> 0.4.3"
end
