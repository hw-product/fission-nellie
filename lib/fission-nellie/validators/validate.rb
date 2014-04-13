module Fission
  module Nellie
    module Validators
      class Validate < Fission::Validators::Validate
      end
    end
  end
end

Fission.register(:nellie, :validators, :validate, Fission::Nellie::Validators::Validate)
