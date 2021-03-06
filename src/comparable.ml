open! Import
open Sexplib.Conv
module Sexp = Sexplib.Sexp
module List = ListLabels

include Comparable_intf

module Validate = Base.Comparable.Validate

module With_zero
    (T : sig
       type t [@@deriving compare, sexp]
       val zero : t
       include Validate with type t := t
     end)
  = Base.Comparable.With_zero(T)

module Validate_with_zero
    (T : sig
       type t [@@deriving compare, sexp]
       val zero : t
     end)
  = Base.Comparable.Validate_with_zero(T)

module Map_and_set_binable_using_comparator (T : sig
    type t [@@deriving bin_io, compare, sexp]
    include Comparator.S with type t := t
  end) = struct
  include T
  module Map = Core_map.Make_binable_using_comparator (T)
  module Set = Core_set.Make_binable_using_comparator (T)
end

module Map_and_set_binable (T : sig type t [@@deriving bin_io, compare, sexp] end) =
  Map_and_set_binable_using_comparator (struct
    include T
    include Comparator.Make (T)
  end)

module Poly (T : sig type t [@@deriving sexp] end) = struct
  module C = struct
    include T
    include Base.Comparable.Poly(T)
  end
  include C
  module Replace_polymorphic_compare = (C : Polymorphic_compare with type t := t)
  module Map = Core_map.Make_using_comparator (C)
  module Set = Core_set.Make_using_comparator (C)
end

module Make_plain_using_comparator (T : sig
    type t [@@deriving sexp_of]
    include Comparator.S with type t := t
  end) : S_plain with type t := T.t and type comparator_witness = T.comparator_witness = struct
  include T
  module M = Base.Comparable.Make_using_comparator(T)
  include M
  module Replace_polymorphic_compare = (M : Polymorphic_compare with type t := t)
  module Map = Core_map.Make_plain_using_comparator (T)
  module Set = Core_set.Make_plain_using_comparator (T)
end

module Make_plain (T : sig
  type t [@@deriving compare, sexp_of]
end) = Make_plain_using_comparator(struct
    include T
    include Comparator.Make (T)
  end)

module Make_using_comparator (T : sig
    type t [@@deriving sexp]
    include Comparator.S with type t := t
  end) : S with type t := T.t and type comparator_witness = T.comparator_witness = struct
  include T
  module M = Base.Comparable.Make_using_comparator(T)
  include M
  module Replace_polymorphic_compare = (M : Polymorphic_compare with type t := t)
  module Map = Core_map.Make_using_comparator (T)
  module Set = Core_set.Make_using_comparator (T)
end

module Make (T : sig
  type t [@@deriving compare, sexp]
end) : S with type t := T.t =
  Make_using_comparator (struct
    include T
    include Comparator.Make (T)
  end)

module Make_binable_using_comparator (T : sig
  type t [@@deriving bin_io, sexp]
  include Comparator.S with type t := t
end) = struct
  include T
  module M = Base.Comparable.Make_using_comparator(T)
  include M
  module Replace_polymorphic_compare = (M : Polymorphic_compare with type t := t)
  module Map = Core_map.Make_binable_using_comparator (T)
  module Set = Core_set.Make_binable_using_comparator (T)
end

module Make_binable (T : sig
  type t [@@deriving bin_io, compare, sexp]
  end) = Make_binable_using_comparator (struct
    include T
    include Comparator.Make (T)
  end)

module Extend(M : Base.Comparable.S)(X : sig type t = M.t [@@deriving sexp] end) =
struct
  module T = struct
    include M
    include (X : sig type t = M.t [@@deriving sexp] end with type t := t)
  end
  include T
  module Replace_polymorphic_compare = (M : Polymorphic_compare_intf.S with type t := t)
  module Map = Core_map.Make_using_comparator (T)
  module Set = Core_set.Make_using_comparator (T)
end

module Extend_binable(M : Base.Comparable.S)
    (X : sig type t = M.t [@@deriving bin_io, sexp] end) =
struct
  module T = struct
    include M
    include (X : sig type t = M.t [@@deriving bin_io, sexp] end with type t := t)
  end
  include T
  module Replace_polymorphic_compare = (M : Polymorphic_compare_intf.S with type t := t)
  module Map = Core_map.Make_binable_using_comparator (T)
  module Set = Core_set.Make_binable_using_comparator (T)
end

module Inherit
  (C : sig type t [@@deriving compare] end)
  (T : sig
    type t [@@deriving sexp]
    val component : t -> C.t
  end) =
  Make (struct
    type t = T.t [@@deriving sexp]
    let compare t t' = C.compare (T.component t) (T.component t')
  end)

module Check_sexp_conversion (M : sig
  type t [@@deriving sexp_of]
  include S with type t := t
  val examples : t list
end) : sig end = struct
  open M

  let%test_unit _ =
    (* These tests all use single element sets and maps, and so do not depend on the
       order in which elements appear in sexps. *)
    List.iter examples ~f:(fun t ->
      let set = Set.of_list [ t ] in
      let set_sexp = Sexp.List [ sexp_of_t t ] in
      assert (Pervasives.(=) set_sexp ([%sexp_of: Set.t] set));
      assert (Set.equal set (Set.t_of_sexp set_sexp));
      let map = Map.of_alist_exn [ t, () ] in
      let map_sexp = Sexp.List [ Sexp.List [ sexp_of_t t; Sexp.List [] ]] in
      assert (Pervasives.(=) map_sexp ([%sexp_of: unit Map.t] map));
      assert (Map.equal (fun () () -> true)
                map (Map.t_of_sexp [%of_sexp: unit] map_sexp)))
  ;;
end

let lexicographic = Base.Comparable.lexicographic

module Stable = struct
  module V1 = struct
    module type S = sig
      type comparable
      type comparator_witness

      module Map : Core_map.Stable.V1.S
        with type key := comparable
        with type comparator_witness := comparator_witness

      module Set : Core_set.Stable.V1.S
        with type elt := comparable
        with type elt_comparator_witness := comparator_witness
    end

    module Make (X : Stable_module_types.S0) = struct
      module Map = Core_map.Stable.V1.Make (X)
      module Set = Core_set.Stable.V1.Make (X)
    end
  end
end
