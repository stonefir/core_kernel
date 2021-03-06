(** This module extends the Base [Binary_searchable_intf] module *)

open Base.Binary_searchable_intf

module type S1_permissions = sig
  open Perms.Export

  type ('a, -'perms) t

  val binary_search           : (('a, [> read]) t, 'a) binary_search
  val binary_search_segmented : (('a, [> read]) t, 'a) binary_search_segmented
end

module type Binary_searchable = sig
  include Binary_searchable
  module type S1_permissions = S1_permissions
end
