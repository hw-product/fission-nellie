require 'fission'
require 'fission-nellie/version'

Fission.service(
  :nellie,
  :configuration => {
    :environment => {
      :description => 'Custom environment variables',
      :type => :hash
    }
  }
)
