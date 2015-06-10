require 'fission'
require 'fission-nellie/version'

module Fission
  module Nellie
    autoload :Melba, 'fission-nellie/melba'
  end
end

Fission.service(
  :nellie,
  :configuration => {
    :environment => {
      :description => 'Custom environment variables',
      :type => :hash
    }
  }
)
