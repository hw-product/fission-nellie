module Fission
  module Nellie
    # Validator callbacks
    module Validators
      # Validate repository has been provided
      class Repository < Fission::Validators::Repository
      end
    end
  end
end

Fission.register(:nellie, :validators, :repository, Fission::Nellie::Validators::Repository)
