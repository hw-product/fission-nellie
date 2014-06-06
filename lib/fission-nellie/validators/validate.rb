module Fission
  module Nellie
    module Validators
      # Validate account has been confirmed
      class Validate < Fission::Validators::Validate
      end
    end
  end
end

Fission.register(:nellie, :validators, :validate, Fission::Nellie::Validators::Validate)
