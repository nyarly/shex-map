#!/usr/bin/env ruby -rubygems
# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name               = 'shex-map'
  gem.version            = File.read('VERSION').chomp
  gem.date               = File.mtime('VERSION').strftime('%Y-%m-%d')

  gem.homepage           = 'https://github.com/nyarly/shex-map'
  gem.license            = 'Unlicense'
  gem.summary            = 'Implementation of the ShExMap extension for Shape Expressions RDF.rb'
  gem.description        = 'Implementation of the ShExMap extension for Shape Expressions RDF.rb'

  gem.authors            = ['Judson Lester']
  gem.email              = 'nyarly@gmail.com'

  gem.platform           = Gem::Platform::RUBY
  gem.files              = %w(AUTHORS CREDITS README.md LICENSE VERSION etc/doap.ttl) + Dir.glob('lib/**/*.rb')
  gem.require_paths      = %w(lib)
  gem.metadata["yard.run"] = "yri" # use "yard" to build full HTML docs.

  gem.required_ruby_version      = '>= 2.2.2'
  gem.requirements               = []

  gem.add_runtime_dependency 'shex', '~> 0.5'
  gem.add_runtime_dependency 'rdf',  '~> 2.2'
end
