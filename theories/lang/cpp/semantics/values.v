(*
 * Copyright (C) BedRock Systems Inc. 2019 Gregory Malecha
 *
 * SPDX-License-Identifier:AGPL-3.0-or-later
 *)
(**
 * The "operational" style definitions about C++.
 *
 * The definitions in this file are based (loosely) on CompCert.
 *)
Require Import Coq.NArith.BinNat.
Require Import Coq.ZArith.BinInt.
Require Import Coq.Strings.Ascii.

Require Import bedrock.lang.cpp.ast.

(** values *)
Parameter val : Type.

Axiom val_dec : forall a b : val, a = b \/ a <> b.

Parameter Vvoid : val.

Parameter ptr : Type.
Parameter ptr_eq_dec : forall (x y : ptr), { x = y } + { x <> y }.

Parameter nullptr : ptr.
Parameter Vptr : ptr -> val.
Parameter Vint : Z -> val.

Definition Vchar (a : Ascii.ascii) : val :=
  Vint (Z.of_N (N_of_ascii a)).
Definition Vbool (b : bool) : val :=
  Vint (if b then 1 else 0).
Definition Vnat (b : nat) : val :=
  Vint (Z.of_nat b).
Definition Vn (b : N) : val :=
  Vint (Z.of_N b).


Parameter is_true : val -> bool.
Axiom is_true_int : forall i,
    is_true (Vint i) = negb (BinIntDef.Z.eqb i 0).

Axiom Vptr_inj : forall p1 p2, Vptr p1 = Vptr p2 -> p1 = p2.
Axiom Vint_inj : forall a b, Vint a = Vint b -> a = b.

(* this is the stack frame *)
Parameter region : Type.
(* this is the thread information *)
Parameter thread_info : Type.


(** pointer offsets
 *)
Parameter offset_ptr : Z -> val -> val.
(* note(gmm): this is not defined according to the C semantics because creating
 * a pointer that goes out of bounds of the object is undefined behavior in C,
 * e.g. [(p + a) - a <> p] if [p + a] is out of bounds.
 *)
Axiom offset_ptr_combine : forall b o o',
    offset_ptr o' (offset_ptr o b) = offset_ptr (o + o') b.
Axiom offset_ptr_0 : forall b,
    offset_ptr 0 b = b.

(* All offsets are valid pointers. todo: This is unsound. *)
Parameter offset_ptr_ : Z -> ptr -> ptr.
Axiom offset_ptr_val : forall v o p, Vptr p = v -> Vptr (offset_ptr_ o p) = offset_ptr o v.

Axiom offset_ptr_combine_ : forall b o o',
    offset_ptr_ o' (offset_ptr_ o b) = offset_ptr_ (o + o') b.
Axiom offset_ptr_0_ : forall b,
    offset_ptr_ 0 b = b.

(** global environments
 *)
Parameter genv : Type.

Parameter has_type : val -> type -> Prop.
Arguments has_type _%Z _.

Definition max_val (bits : size) (sgn : signed) : Z :=
  match bits , sgn with
  | W8   , Signed   => 2^7 - 1
  | W8   , Unsigned => 2^8 - 1
  | W16  , Signed   => 2^15 - 1
  | W16  , Unsigned => 2^16 - 1
  | W32  , Signed   => 2^31 - 1
  | W32  , Unsigned => 2^32 - 1
  | W64  , Signed   => 2^63 - 1
  | W64  , Unsigned => 2^64 - 1
  | W128 , Signed   => 2^127 - 1
  | W128 , Unsigned => 2^128 - 1
  end%Z.

Definition min_val (bits : size) (sgn : signed) : Z :=
  match sgn with
  | Unsigned => 0
  | Signed =>
    match bits with
    | W8   => -2^7
    | W16  => -2^15
    | W32  => -2^31
    | W64  => -2^63
    | W128 => -2^127
    end
  end%Z.

Axiom has_type_pointer : forall v ty, has_type v (Tpointer ty) -> exists p, v = Vptr p.

Definition bound (bits : size) (sgn : signed) (v : Z) : Prop :=
  (min_val bits sgn <= v <= max_val bits sgn)%Z.

Arguments Z.add _ _ : simpl never.
Arguments Z.sub _ _ : simpl never.
Arguments Z.mul _ _ : simpl never.
Arguments Z.pow _ _ : simpl never.
Arguments Z.opp _ : simpl never.
Arguments Z.pow_pos _ _ : simpl never.

Axiom has_int_type : forall sz (sgn : signed) z,
    bound sz sgn z <-> has_type (Vint z) (Tint sz sgn).

Axiom has_char_type : forall sz (sgn : signed) z,
    bound sz sgn z <-> has_type (Vint z) (Tchar sz sgn).

Axiom has_type_qual : forall t q x,
    has_type x (drop_qualifiers t) ->
    has_type x (Tqualified q t).

Hint Resolve has_type_qual : has_type.




(* address of a global variable *)
Parameter glob_addr : genv -> obj_name -> option ptr.

(* todo(gmm): this isn't sound due to reference fields *)
Parameter offset_of : forall (resolve : genv) (t : globname) (f : ident), option Z.
Parameter parent_offset : forall (resolve : genv) (t : globname) (f : globname), option Z.

Parameter pointer_size : genv -> N. (* in bytes *)


(* sizeof() *)
(* [size_of] requires a well-founded type environment in order to be
 * implementable as a function.
 *)
Parameter size_of : forall (resolve : genv) (t : type), option N.

(* it is hard to define [size_of] as a function because it needs
to recurse through the environment in the case of [Treference]:
termination will require a proof of well-foundedness of the environment *)
Axiom size_of_int : forall {c : genv} s w,
    @size_of c (Tint w s) = Some (N.div (N_of_size w + 7) 8).
Axiom size_of_char : forall {c : genv} s w,
    @size_of c (Tchar w s) = Some (N.div (N_of_size w + 7) 8).
Axiom size_of_bool : forall {c : genv},
    @size_of c Tbool = Some 1%N.
Axiom size_of_pointer : forall {c : genv} t,
    @size_of c (Tpointer t) = Some (pointer_size c).
Axiom size_of_qualified : forall {c : genv} t q,
    @size_of c t = @size_of c (Tqualified q t).
Axiom size_of_array : forall {c : genv} t n sz,
    @size_of c t = Some sz ->
    @size_of c (Tarray t n) = Some (sz * n)%N.

Lemma size_of_Qmut : forall {c} t,
    @size_of c t = @size_of c (Qmut t).
Proof.
  intros.
  now apply size_of_qualified.
Qed.

Lemma size_of_Qconst : forall {c} t ,
    @size_of c t = @size_of c (Qconst t).
Proof.
  intros.
  now apply size_of_qualified.
Qed.

(* alignof() *)
Parameter align_of : forall {resolve : genv} (t : type), option N.

(* truncation (used for unsigned operations) *)
Definition trim (w : N) (v : Z) : Z := v mod (2 ^ Z.of_N w).