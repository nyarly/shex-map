# vi: ft=ruby:
RSpec.configure do |config|
  config.pattern = 'spec/**/*.rb'
  config.example_status_persistence_file_path = '/tmp/shex-map.failures'
end
