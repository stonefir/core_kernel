(** [Info] is a library for lazily constructing human-readable information as a string or
    sexp, with a primary use being error messages.  Using [Info] is often preferable to
    [sprintf] or manually constructing strings because you don't have to eagerly construct
    the string --- you only need to pay when you actually want to display the info.  which
    for many applications is rare.  Using [Info] is also better than creating custom
    exceptions because you have more control over the format.

    Info is intended to be constructed in the following style; for simple info, you write:

    {[Info.of_string "Unable to find file"]}

    Or for a more descriptive [Info] without attaching any content (but evaluating the
    result eagerly):

    {[Info.createf "Process %s exited with code %d" process exit_code]}

    For info where you want to attach some content, you would write:

    {[Info.create "Unable to find file" filename <:sexp_of< string >>]}

    Or even,

    {[
    Info.create "price too big" (price, [`Max max_price])
      (<:sexp_of< float * [`Max of float] >>)
    ]}

    Note that an [Info.t] can be created from any arbritrary sexp with [Info.t_of_sexp].
*)

open! Import

module type S = sig
  open Sexplib

  (** Serialization and comparison force the lazy message. *)
  type t [@@deriving bin_io, compare, hash, sexp]

  include Base0.Invariant_intf.S with type t := t

  (** [to_string_hum] forces the lazy message, which might be an expensive operation.

      [to_string_hum] usually produces a sexp; however, it is guaranteed that [to_string_hum
      (of_string s) = s].

      If this string is going to go into a log file, you may find it useful to ensure that
      the string is only one line long.  To do this, use [to_string_mach t].
  *)
  val to_string_hum : t -> string

  (** [to_string_mach t] outputs [t] as a sexp on a single-line. *)
  val to_string_mach : t -> string

  (** old version (pre 109.61) of [to_string_hum] that some applications rely on.

      Calls should be replaced with [to_string_mach t], which outputs more parenthesis and
      backslashes.
  *)
  val to_string_hum_deprecated : t -> string

  val of_string : string -> t

  (** Be careful that the body of the lazy or thunk does not access mutable data, since it
      will only be called at an undetermined later point. *)
  val of_lazy  : string Lazy.t    -> t
  val of_thunk : (unit -> string) -> t

  (** For [create message a sexp_of_a], [sexp_of_a a] is lazily computed, when the info is
      converted to a sexp.  So, if [a] is mutated in the time between the call to [create]
      and the sexp conversion, those mutations will be reflected in the sexp.  Use
      [~strict:()] to force [sexp_of_a a] to be computed immediately. *)
  val create
    :  ?here   : Source_code_position0.t
    -> ?strict : unit
    -> string
    -> 'a
    -> ('a -> Sexp.t)
    -> t

  val create_s : Sexp.t -> t

  (** Construct a [t] containing only a string from a format.  This eagerly constructs
      the string. *)
  val createf : ('a, unit, string, t) format4 -> 'a

  (** Add a string to the front. *)
  val tag : t -> tag:string -> t

  (** Add a string and some other data in the form of an s-expression at the front. *)
  val tag_arg : t -> string -> 'a -> ('a -> Sexp.t) -> t

  (** Combine multiple infos into one *)
  val of_list : ?trunc_after:int -> t list -> t

  (** [of_exn] and [to_exn] are primarily used with [Error], but their definitions have to
     be here because they refer to the underlying representation. *)
  val of_exn : ?backtrace:[ `Get | `This of string ] -> exn -> t
  val to_exn : t -> exn

  val pp : Format.formatter -> t -> unit

  module Stable : sig
    (** [Info.t] is wire-compatible with [V2.t], but not [V1.t].  [V1] bin-prots a sexp of
        the underlying message, whereas [V2] bin-prots the underlying message. *)
    module V1 : Stable_module_types.S0 with type t = t
    module V2 : Stable_module_types.S0 with type t = t
  end
end
