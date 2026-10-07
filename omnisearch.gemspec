# frozen_string_literal: true

require_relative 'lib/omnisearch/version'

Gem::Specification.new do |spec|
  spec.name        = 'omnisearch'
  spec.version     = Omnisearch::VERSION
  spec.authors     = ['Eleazar Meza']
  spec.email       = ['meza.eleazar@gmail.com']

  spec.summary     = 'A mountable search engine for Rails apps, with pluggable providers.'
  spec.description = <<~DESC
    Omnisearch is a Rails engine that gives a host app a /search endpoint backed by
    one or more search providers. Providers are registered by class, so a host can
    add its own without changing the engine. Caching uses whatever Rails.cache is
    already configured as, and a cache outage degrades to no caching rather than
    failing the request.

    Not yet published to RubyGems. Install from GitHub:
      gem "omnisearch", github: "zarmeza/omnisearch"

    Successor to the archived https://github.com/zarmeza/omnisearch-rails, whose
    request and response contract this gem preserves.
  DESC
  spec.homepage    = 'https://github.com/zarmeza/omnisearch'
  spec.license     = 'MIT'
  spec.required_ruby_version = '>= 3.3.0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = spec.homepage
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir[
    'lib/**/*.rb',
    'app/**/*.rb',
    'config/routes.rb',
    'README.md',
    'LICENSE.txt',
    'CHANGELOG.md'
  ]
  spec.require_paths = ['lib']

  spec.add_dependency 'httparty', '~> 0.24'
  spec.add_dependency 'nokogiri', '>= 1.16', '< 2.0'
  spec.add_dependency 'railties', '>= 7.2'
end
