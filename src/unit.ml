open! Import

module T0 = struct
  open Typerep_lib.Std
  open Sexplib.Std
  open Bin_prot.Std
  open Hash.Builtin

  type t = unit [@@deriving hash, sexp, bin_io, typerep]

  let compare _ _ = 0
end

module T1 = struct
  include T0
  include Sexpable.To_stringable (T0)
  let module_name = "Core.Std.Unit"
end

include T1
include Identifiable.Make (T1)

let invariant () = ()

let gen      = Quickcheck.Generator.singleton ()
let obs      = Quickcheck.Observer.singleton  ()
let shrinker = Quickcheck.Shrinker.empty      ()

module type S = sig end

type m = (module S)
