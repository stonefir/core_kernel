open! Import
open Core_map_intf
open Sexplib

module Symmetric_diff_element = Symmetric_diff_element

module List = Core_list

open! Int_replace_polymorphic_compare

module For_quickcheck = struct

  module Generator = Quickcheck.Generator
  module Observer  = Quickcheck.Observer
  module Shrinker  = Quickcheck.Shrinker
  module Map = Map.Using_comparator

  open Generator.Monad_infix

  let gen_alist k_gen v_gen ~comparator =
    List.gen k_gen
    >>= fun ks ->
    let ks = List.dedup ks ~compare:comparator.Comparator.compare in
    List.gen' v_gen ~length:(`Exactly (List.length ks))
    >>| fun vs ->
    List.zip_exn ks vs

  let gen_tree ~comparator k_gen v_gen =
    gen_alist k_gen v_gen ~comparator
    >>| Tree.of_alist_exn ~comparator

  let gen ~comparator k_gen v_gen =
    gen_alist k_gen v_gen ~comparator
    >>| Map.of_alist_exn ~comparator

  let obs_alist k_obs v_obs =
    List.obs (Observer.tuple2 k_obs v_obs)

  let obs_tree k_obs v_obs =
    Observer.unmap (obs_alist k_obs v_obs)
      ~f:Tree.to_alist

  let obs k_obs v_obs =
    Observer.unmap (obs_alist k_obs v_obs)
      ~f:Map.to_alist

  let shrink k_shr v_shr t =
    let seq = Map.to_sequence t in
    let drop_keys =
      Sequence.map seq ~f:(fun (k, _) ->
        Map.remove t k)
    in
    let shrink_keys =
      Sequence.interleave (Sequence.map seq ~f:(fun (k, v) ->
        Sequence.map (Shrinker.shrink k_shr k) ~f:(fun k' ->
          Map.add (Map.remove t k) ~key:k' ~data:v)))
    in
    let shrink_values =
      Sequence.interleave (Sequence.map seq ~f:(fun (k, v) ->
        Sequence.map (Shrinker.shrink v_shr v) ~f:(fun v' ->
          Map.add t ~key:k ~data:v')))
    in
    [ drop_keys; shrink_keys; shrink_values ]
    |> Sequence.of_list
    |> Sequence.interleave

  let shr_tree ~comparator k_shr v_shr =
    Shrinker.create (fun tree ->
      Map.of_tree ~comparator tree
      |> shrink k_shr v_shr
      |> Sequence.map ~f:Map.to_tree)

  let shrinker k_shr v_shr =
    Shrinker.create (fun t ->
      shrink k_shr v_shr t)

end

let gen = For_quickcheck.gen
let obs = For_quickcheck.obs
let shrinker = For_quickcheck.shrinker

module Accessors = struct
  include (Map.Using_comparator : Map_intf.Accessors3
             with type ('a, 'b, 'c) t    := ('a, 'b, 'c) Map.t
             with type ('a, 'b, 'c) tree := ('a, 'b, 'c) Tree .t)

  let obs k v = obs k v
  let shrinker k v = shrinker k v
end

include (Map.Using_comparator :
           module type of struct include Map.Using_comparator end
           with module Tree := Tree)

let of_hashtbl_exn ~comparator hashtbl =
  match of_iteri ~comparator ~iteri:(Core_hashtbl.iteri hashtbl) with
  | `Ok map -> map
  | `Duplicate_key key ->
    Error.failwiths "Map.of_hashtbl_exn: duplicate key" key comparator.sexp_of_t
;;

let tree_of_hashtbl_exn ~comparator hashtbl =
  to_tree (of_hashtbl_exn ~comparator hashtbl)

module Creators (Key : Comparator.S1) : sig

  type ('a, 'b, 'c) t_ = ('a Key.t, 'b, Key.comparator_witness) t
  type ('a, 'b, 'c) tree =
    ('a, 'b, Key.comparator_witness) Tree.t
  type ('a, 'b, 'c) options = ('a, 'b, 'c) Without_comparator.t

  val t_of_sexp : (Sexp.t -> 'a Key.t) -> (Sexp.t -> 'b) -> Sexp.t -> ('a, 'b, _) t_

  include Creators_generic
    with type ('a, 'b, 'c) t    := ('a, 'b, 'c) t_
    with type ('a, 'b, 'c) tree := ('a, 'b, 'c) tree
    with type 'a key := 'a Key.t
    with type ('a, 'b, 'c) options := ('a, 'b, 'c) options

end = struct
  type ('a, 'b, 'c) options = ('a, 'b, 'c) Without_comparator.t

  let comparator = Key.comparator

  type ('a, 'b, 'c) t_ = ('a Key.t, 'b, Key.comparator_witness) t

  type ('a, 'b, 'c) tree =
    ('a, 'b, Key.comparator_witness) Tree.t

  module M_empty = Empty_without_value_restriction(Key)
  let empty = M_empty.empty

  let of_tree tree = of_tree ~comparator tree

  let singleton k v = singleton ~comparator k v

  let of_sorted_array_unchecked array = of_sorted_array_unchecked ~comparator array

  let of_sorted_array array = of_sorted_array ~comparator array

  let of_increasing_iterator_unchecked ~len ~f =
    of_increasing_iterator_unchecked ~comparator ~len ~f

  let of_alist alist = of_alist ~comparator alist

  let of_alist_or_error alist = of_alist_or_error ~comparator alist

  let of_alist_exn alist = of_alist_exn ~comparator alist

  let of_hashtbl_exn hashtbl = of_hashtbl_exn ~comparator hashtbl

  let of_alist_multi alist = of_alist_multi ~comparator alist

  let of_alist_fold alist ~init ~f = of_alist_fold ~comparator alist ~init ~f

  let of_alist_reduce alist ~f = of_alist_reduce ~comparator alist ~f

  let of_iteri ~iteri = of_iteri ~comparator ~iteri

  let t_of_sexp k_of_sexp v_of_sexp sexp =
    t_of_sexp_direct ~comparator k_of_sexp v_of_sexp sexp

  let gen gen_k gen_v = gen ~comparator gen_k gen_v

end

module Make_tree (Key : Comparator.S1) = struct
  open Tree
  let comparator = Key.comparator

  let sexp_of_t = sexp_of_t
  let t_of_sexp a b c = t_of_sexp_direct a b c ~comparator
  let empty = empty_without_value_restriction
  let of_tree tree = tree
  let singleton a = singleton a ~comparator
  let of_sorted_array_unchecked a = of_sorted_array_unchecked a ~comparator
  let of_sorted_array a = of_sorted_array a ~comparator
  let of_increasing_iterator_unchecked ~len ~f =
    of_increasing_iterator_unchecked ~len ~f ~comparator
  let of_alist a = of_alist a ~comparator
  let of_alist_or_error a = of_alist_or_error a ~comparator
  let of_alist_exn a = of_alist_exn a ~comparator
  let of_hashtbl_exn a = tree_of_hashtbl_exn a ~comparator
  let of_alist_multi a = of_alist_multi a ~comparator
  let of_alist_fold a ~init ~f = of_alist_fold a ~init ~f ~comparator
  let of_alist_reduce a ~f = of_alist_reduce a ~f ~comparator
  let of_iteri ~iteri = of_iteri ~iteri ~comparator
  let to_tree t = t
  let invariants a = invariants a ~comparator
  let is_empty a = is_empty a
  let length a = length a
  let add a ~key ~data = add a ~key ~data ~comparator
  let add_multi a ~key ~data = add_multi a ~key ~data ~comparator
  let remove_multi a b = remove_multi a b ~comparator
  let change a b ~f = change a b ~f ~comparator
  let update a b ~f = update a b ~f ~comparator
  let find_exn a b = find_exn a b ~comparator
  let find a b = find a b ~comparator
  let remove a b = remove a b ~comparator
  let mem a b = mem a b ~comparator
  let iter_keys = iter_keys
  let iter = iter
  let iteri = iteri
  let iter2 a b ~f = iter2 a b ~f ~comparator
  let map = map
  let mapi = mapi
  let fold = fold
  let fold_right = fold_right
  let fold2 a b ~init ~f = fold2 a b ~init ~f ~comparator
  let filter_keys a ~f = filter_keys a ~f ~comparator
  let filter a ~f = filter a ~f ~comparator
  let filteri a ~f = filteri a ~f ~comparator
  let filter_map a ~f = filter_map a ~f ~comparator
  let filter_mapi a ~f = filter_mapi a ~f ~comparator
  let partition_mapi t ~f = partition_mapi t ~f ~comparator
  let partition_map t ~f = partition_map t ~f ~comparator
  let partitioni_tf t ~f = partitioni_tf t ~f ~comparator
  let partition_tf t ~f = partition_tf t ~f ~comparator
  let compare_direct a b c = compare_direct a b c ~comparator
  let equal a b c = equal a b c ~comparator
  let keys = keys
  let data = data
  let to_alist = to_alist
  let validate = validate
  let symmetric_diff a b ~data_equal = symmetric_diff a b ~data_equal ~comparator
  let merge a b ~f = merge a b ~f ~comparator
  let min_elt = min_elt
  let min_elt_exn = min_elt_exn
  let max_elt = max_elt
  let max_elt_exn = max_elt_exn
  let for_all = for_all
  let for_alli = for_alli
  let exists = exists
  let existsi = existsi
  let count = count
  let counti = counti
  let split a b = split a b ~comparator
  let fold_range_inclusive t ~min ~max ~init ~f =
    fold_range_inclusive t ~min ~max ~init ~f ~comparator
  let range_to_alist t ~min ~max = range_to_alist t ~min ~max ~comparator
  let closest_key a b c = closest_key a b c ~comparator
  let nth a = nth a ~comparator
  let nth_exn a = nth_exn a ~comparator
  let rank a b = rank a b ~comparator

  let to_sequence ?order ?keys_greater_or_equal_to ?keys_less_or_equal_to t =
    to_sequence ~comparator ?order ?keys_greater_or_equal_to
      ?keys_less_or_equal_to t

  let gen k v =
    For_quickcheck.gen_tree ~comparator k v

  let obs k v =
    For_quickcheck.obs_tree k v

  let shrinker k v =
    For_quickcheck.shr_tree ~comparator k v
end

(* Don't use [of_sorted_array] to avoid the allocation of an intermediate array *)
let init_for_bin_prot ~len ~f ~comparator =
  let map = of_increasing_iterator_unchecked ~len ~f ~comparator in
  if invariants map
  then map
  else
    (* The invariants are broken, but we can still traverse the structure. *)
    match of_iteri ~iteri:(iteri map) ~comparator with
    | `Ok map -> map
    | `Duplicate_key _key ->
      failwith "Map.bin_read_t: duplicate element in map"
;;

module Poly = struct
  include Creators (Comparator.Poly)

  type ('a, 'b, 'c) map = ('a, 'b, 'c) t
  type ('k, 'v) t = ('k, 'v, Comparator.Poly.comparator_witness) map

  include Accessors

  let compare _ cmpv t1 t2 = compare_direct cmpv t1 t2

  let sexp_of_t sexp_of_k sexp_of_v t = sexp_of_t sexp_of_k sexp_of_v [%sexp_of: _] t

  include Bin_prot.Utils.Make_iterable_binable2 (struct
      type nonrec ('a, 'b) t = ('a, 'b) t
      type ('a, 'b) el = 'a * 'b [@@deriving bin_io]
      let _ = bin_el
      let caller_identity = Bin_prot.Shape.Uuid.of_string "b7d7b1a0-4992-11e6-8a32-bbb221fa025c"
      let module_name = Some "Core.Std.Map"
      let length = length
      let iter t ~f = iteri t ~f:(fun ~key ~data -> f (key, data))
      let init ~len ~next =
        init_for_bin_prot
          ~len
          ~f:(fun _ -> next ())
          ~comparator:Comparator.Poly.comparator
    end)


  module Tree = struct
    include Make_tree (Comparator.Poly)
    type ('k, +'v) t = ('k, 'v, Comparator.Poly.comparator_witness) tree
    let sexp_of_t sexp_of_k sexp_of_v t = sexp_of_t sexp_of_k sexp_of_v [%sexp_of: _] t
  end
end

module type Key_plain   = Key_plain
module type Key         = Key
module type Key_binable = Key_binable
module type Key_hashable = Key_hashable
module type Key_binable_hashable = Key_binable_hashable

module type S_plain   = S_plain
module type S         = S
module type S_binable = S_binable

module Make_plain_using_comparator (Key : sig
    type t [@@deriving sexp_of]
    include Comparator.S with type t := t
  end) = struct

  module Key = Key

  module Key_S1 = Comparator.S_to_S1 (Key)
  include Creators (Key_S1)

  type key = Key.t
  type ('a, 'b, 'c) map = ('a, 'b, 'c) t
  type 'v t = (key, 'v, Key.comparator_witness) map

  include Accessors

  let compare cmpv t1 t2 = compare_direct cmpv t1 t2

  let sexp_of_t sexp_of_v t = sexp_of_t Key.sexp_of_t sexp_of_v [%sexp_of: _] t

  module Provide_of_sexp (Key : sig type t [@@deriving of_sexp] end with type t := Key.t) =
  struct
    let t_of_sexp v_of_sexp sexp = t_of_sexp Key.t_of_sexp v_of_sexp sexp
  end

  module Provide_hash (Key' : Hasher.S with type t := Key.t) = struct
    let hash_fold_t (type a) hash_fold_data state (t : a t)  =
      hash_fold_direct Key'.hash_fold_t hash_fold_data state t
  end

  module Provide_bin_io (Key' : sig type t [@@deriving bin_io] end with type t := Key.t) =
    Bin_prot.Utils.Make_iterable_binable1 (struct
      module Key = struct include Key include Key' end
      type nonrec 'v t = 'v t
      type 'v el = Key.t * 'v [@@deriving bin_io]
      let _ = bin_el
      let caller_identity = Bin_prot.Shape.Uuid.of_string "dfb300f8-4992-11e6-9c15-73a2ac6b815c"
      let module_name = Some "Core.Std.Map"
      let length = length
      let iter t ~f = iteri t ~f:(fun ~key ~data -> f (key, data))
      let init ~len ~next =
        init_for_bin_prot
          ~len
          ~f:(fun _ -> next ())
          ~comparator:Key.comparator
    end)

  module Tree = struct
    include Make_tree (Key_S1)
    type +'v t = (Key.t, 'v, Key.comparator_witness) tree

    let sexp_of_t sexp_of_v t = sexp_of_t Key.sexp_of_t sexp_of_v [%sexp_of: _] t

    module Provide_of_sexp (X : sig type t [@@deriving of_sexp] end with type t := Key.t) =
    struct
      let t_of_sexp v_of_sexp sexp = t_of_sexp X.t_of_sexp v_of_sexp sexp
    end
  end
end

module Make_plain (Key : Key_plain) =
  Make_plain_using_comparator (struct
    include Key
    include Comparator.Make (Key)
  end)

module Make_using_comparator
    (Key : sig type t [@@deriving sexp] include Comparator.S with type t := t end) =
struct
  module Key = Key
  module M1 = Make_plain_using_comparator (Key)
  include (M1 : module type of M1 with module Tree := M1.Tree with module Key := Key)
  include Provide_of_sexp (Key)
  module Tree = struct
    include M1.Tree
    include Provide_of_sexp (Key)
  end
end

module Make (Key : Key) =
  Make_using_comparator (struct
    include Key
    include Comparator.Make (Key)
  end)

module Make_binable_using_comparator (Key : sig
  type t [@@deriving bin_io, sexp]
  include Comparator.S with type t := t
end) = struct
  module Key = Key
  module M2 = Make_using_comparator (Key)
  include (M2 : module type of M2 with module Key := Key)
  include Provide_bin_io (Key)
end

module Make_binable (Key : Key_binable) =
  Make_binable_using_comparator (struct
    include Key
    include Comparator.Make (Key)
  end)

module Tree = struct
  include Tree
  let of_hashtbl_exn = tree_of_hashtbl_exn
  let gen ~comparator k v =
    For_quickcheck.gen_tree ~comparator k v
  let obs k v =
    For_quickcheck.obs_tree k v
  let shrinker ~comparator k v =
    For_quickcheck.shr_tree ~comparator k v
end

module Stable = struct
  module V1 = struct
    type nonrec ('k, 'v, 'cmp) t = ('k, 'v, 'cmp) t

    module type S = sig
      type key
      type comparator_witness
      type nonrec 'a t = (key, 'a, comparator_witness) t
      include Stable_module_types.S1 with type 'a t := 'a t
    end

    module Make (Key : Stable_module_types.S0) = Make_binable_using_comparator (Key)
  end
end
