module Fission
  module Nellie
    module Validators
      class Repository < Fission::Validators::Repository
      end
    end
  end
end

Fission.register(:nellie, :validators, :repository, Fission::Nellie::Validators::Repository)
