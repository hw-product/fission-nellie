module Fission
  module Nellie
    # Custom version class
    class Version < Gem::Version
    end
    # Current library version
    VERSION = Version.new('0.1.1')
  end
end
