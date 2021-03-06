(** This module extends the Base [Either] module *)

type ('f, 's) t = ('f, 's) Base.Either.t =
  | First  of 'f
  | Second of 's
[@@deriving bin_io, typerep]

include module type of struct include Base.Either end with type ('f, 's) t := ('f, 's) t

include Quickcheckable.S2 with type ('a, 'b) t := ('a, 'b) t

module Stable : sig
  module V1 : sig
    type nonrec ('f, 's) t
      = ('f, 's) t
      = First  of 'f
      | Second of 's
    include Stable_module_types.S2 with type ('f, 's) t := ('f, 's) t
  end
end
