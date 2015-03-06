$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'fission-nellie/version'
Gem::Specification.new do |s|
  s.name = 'fission-nellie'
  s.version = Fission::Nellie::VERSION.version
  s.summary = 'Fission Nellie'
  s.author = 'Heavywater'
  s.email = 'fission@hw-ops.com'
  s.homepage = 'http://github.com/heavywater/fission-nellie'
  s.description = 'Do things'
  s.require_path = 'lib'
  s.add_dependency 'fission'
  s.add_dependency 'elecksee'
  s.add_dependency 'jackal-nellie'
  s.files = Dir['lib/**/**/*'] + %w(fission-nellie.gemspec README.md CHANGELOG.md)
end
