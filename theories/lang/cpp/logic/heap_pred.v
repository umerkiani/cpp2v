(*
 * Copyright (C) BedRock Systems Inc. 2019 Gregory Malecha
 *
 * SPDX-License-Identifier:AGPL-3.0-or-later
 *)
Require Import Coq.Classes.Morphisms.
Require Import Coq.NArith.BinNat.
Require Import Coq.ZArith.BinInt.
Require Import Coq.Strings.String.

From iris.bi Require Export monpred.

From bedrock.lang.cpp Require Import semantics logic.pred ast.

Local Open Scope string_scope.

(* representations are predicates over a location, they should be used to
 * assert properties of the heap
 *)
Global Instance val_inhabited : Inhabited val.
Proof. constructor. apply (Vint 0). Qed.
Global Instance ptr_inhabited : Inhabited ptr.
Proof. constructor. apply nullptr. Qed.

Local Instance ptr_rel : SqSubsetEq ptr.
Proof.
  unfold SqSubsetEq.
  unfold relation.
  apply eq.
Defined.

Local Instance ptr_rel_preorder : PreOrder (⊑@{ptr}).
Proof.
  unfold sqsubseteq. unfold ptr_rel.
  apply base.PreOrder_instance_0.
Qed.

Canonical Structure ptr_bi_index : biIndex :=
  BiIndex ptr ptr_inhabited ptr_rel ptr_rel_preorder.

Definition Rep Σ := (monPred ptr_bi_index (mpredI Σ)).
Definition RepI Σ := (monPredI ptr_bi_index (mpredI Σ)).
Definition RepSI Σ := (monPredSI ptr_bi_index (mpredSI Σ)).

Lemma monPred_at_persistent_inv {V bi} (P : monPred V bi) :
  (∀ i, Persistent (P i)) → Persistent P.
Proof. intros HP. constructor=> i. MonPred.unseal. apply HP. Qed.

Lemma monPred_at_timeless_inv {V sbi} (P : monPredSI V sbi) :
  (∀ i, Timeless (P i)) → Timeless P.
Proof. intros HP. constructor=> i. MonPred.unseal. apply HP. Qed.

Lemma Rep_lequiv {Σ} : forall (P Q : Rep Σ),
    (forall p, P p -|- Q p) ->
    P -|- Q.
Proof.
  intros. split; constructor; apply H.
Qed.


(* locations are computations that produce an address.
 * - note(gmm): they are always computable from the program except.
 *)
Definition Loc : Type := option ptr.

Definition Offset : Type := option (ptr -> option ptr).

Section with_Σ.
Context {Σ : gFunctors}.

Local Notation mpred := (mpred Σ) (only parsing).
Local Notation Rep := (Rep Σ) (only parsing).

Local Ltac solve_Rep_persistent X :=
  intros;
  rewrite X;
  constructor; apply monPred_at_persistent_inv;
  apply _.
Local Ltac solve_Loc_persistent X :=
  intros;
  rewrite X;
  constructor; apply monPred_at_persistent_inv;
  apply _.
Local Ltac solve_Offset_persistent X :=
  intros;
  rewrite X;
  constructor; apply monPred_at_persistent_inv;
  constructor; apply monPred_at_persistent_inv;
  apply _.

Local Ltac solve_Rep_timeless X :=
  intros;
  rewrite X;
  constructor; apply monPred_at_timeless_inv;
  apply _.
Local Ltac solve_Loc_timeless X :=
  intros;
  rewrite X;
  constructor; apply monPred_at_timeless_inv;
  apply _.
Local Ltac solve_Offset_timeless X :=
  intros;
  rewrite X;
  constructor; apply monPred_at_timeless_inv;
  constructor; apply monPred_at_timeless_inv;
  apply _.

Definition as_Rep (P : ptr -> mpred) : Rep := MonPred P _.

Lemma Rep_equiv_ext_equiv : forall P Q : Rep,
    (forall x, P x -|- Q x) ->
    P -|- Q.
Proof.
  split; red; simpl; eapply H.
Qed.

Definition LocEq (l1 l2 : Loc) : Prop :=
  l1 = l2.

(* absolute locations *)
Definition _eq_def (p : ptr) : Loc :=
  Some p.
Definition _eq_aux : seal (@_eq_def). by eexists. Qed.
Definition _eq := _eq_aux.(unseal).
Definition _eq_eq : @_eq = _ := _eq_aux.(seal_eq).


Definition _eqv (a : val) : Loc :=
  match a with
  | Vptr p => _eq p
  | _ => None
  end.

Lemma _eqv_eq : forall p, _eqv (Vptr p) = _eq p.
Proof. reflexivity. Qed.

(* val -> ptr *)
Definition this_addr (r : region) (p : ptr) : mpred :=
  local_addr r "#this" p.

(* val -> ptr *)
Definition result_addr (r : region) (p : ptr) : mpred :=
  local_addr r "#result" p.

(* ^ these two could be duplicable because regions don't need to be
 * reused. the reason that local variables need to be tracked is that
 * they could go out of scope.
 * - an alternative, and (sound) solution is to generate a fresh region
 *   each time that we create a new scope. To do this, we need to track in
 *   the AST the debruijn index of the binder.
 * - yet another alternative is to inline regions explicitly into the WP.
 *   essentially region := list (list (string * ptr)). this essentially makes
 *   _local persistent.
 *)

Definition _global_def (resolve : genv) (x : obj_name) : Loc :=
  match glob_addr resolve x with
  | None => None
  | Some p => Some p
  end.
Definition _global_aux : seal (@_global_def). by eexists. Qed.
Definition _global := _global_aux.(unseal).
Definition _global_eq : @_global = _ := _global_aux.(seal_eq).

(* offsets *)
Definition _field_def (resolve: genv) (f : field) : Offset :=
  match offset_of resolve f.(f_type) f.(f_name) with
  | Some o => Some (fun p => Some (offset_ptr_ o p))
  | _ => None
  end.
Definition _field_aux : seal (@_field_def). Proof using. by eexists. Qed.
Definition _field := _field_aux.(unseal).
Definition _field_eq : @_field = _ := _field_aux.(seal_eq).

Definition _sub_def (resolve:genv) (t : type) (i : Z) : Offset :=
  match size_of resolve t with
  | Some n => Some (fun p => Some (offset_ptr_ (i * Z.of_N n) p))
  | _ => None
  end.
Definition _sub_aux : seal (@_sub_def). by eexists. Qed.
Definition _sub := _sub_aux.(unseal).
Definition _sub_eq : @_sub = _ := _sub_aux.(seal_eq).


(* this represents static_cast *)
Definition _super_def (resolve:genv) (sub super : globname) : Offset :=
  match parent_offset resolve sub super with
  | Some o => Some (fun p => Some (offset_ptr_ o p))
  | _ => None
  end.
Definition _super_aux : seal (@_super_def). by eexists. Qed.
Definition _super := _super_aux.(unseal).
Definition _super_eq : @_super = _ := _super_aux.(seal_eq).

Definition _id_def : Offset := Some (fun x => Some x).
Definition _id_aux : seal (@_id_def). by eexists. Qed.
Definition _id := _id_aux.(unseal).
Definition _id_eq : @_id = _ := _id_aux.(seal_eq).

Definition _dot_def (o1 o2 : Offset) : Offset :=
  match o1 , o2 with
  | Some o1 , Some o2 => Some (fun x => match o1 x with
                                    | None => None
                                    | Some p => o2 p
                                    end)
  | _ , _ => None
  end.
Definition _dot_aux : seal (@_dot_def). by eexists. Qed.
Definition _dot := _dot_aux.(unseal).
Definition _dot_eq : @_dot = _ := _dot_aux.(seal_eq).

Definition _offsetL_def (o : Offset) (l : Loc) : Loc :=
  match o , l with
  | Some o , Some l => match o l with
                      | None => None
                      | Some p => Some p
                      end
  | _ , _ => None
  end.
Definition _offsetL_aux : seal (@_offsetL_def). by eexists. Qed.
Definition _offsetL := _offsetL_aux.(unseal).
Definition _offsetL_eq : @_offsetL = _ := _offsetL_aux.(seal_eq).



Definition _offsetR_def (o : Offset) (r : Rep) : Rep :=
  as_Rep (fun a => match o with
                | Some o => match o a with
                           | None => lfalse
                           | Some p => r p
                           end
                | None => lfalse
                end).
Definition _offsetR_aux : seal (@_offsetR_def). by eexists. Qed.
Definition _offsetR := _offsetR_aux.(unseal).
Definition _offsetR_eq : @_offsetR = _ := _offsetR_aux.(seal_eq).

Global Instance _offsetR_persistent o r :
  Persistent r -> Persistent (_offsetR o r).
Proof. solve_Rep_persistent _offsetR_eq. Qed.
Global Instance Proper__offsetR_entails
  : Proper (eq ==> lentails ==> lentails) _offsetR.
Proof.
  rewrite _offsetR_eq. unfold _offsetR_def.
  constructor. simpl. intros.
  subst. destruct y; auto. destruct (o i); auto. apply H0.
Qed.

Global Instance Proper__offsetR_equiv
  : Proper (eq ==> lequiv ==> lequiv) _offsetR.
Proof.
  rewrite _offsetR_eq.
  intros ?? H1 ?? H2.
  constructor. simpl.
  intros. subst. split'; destruct y; try rewrite H2; eauto.
  all: destruct (o i); eauto; rewrite H2; reflexivity.
Qed.


Definition addr_of_def (a : Loc) (b : ptr) : mpred :=
  [| a = Some b |].
Definition addr_of_aux : seal (@addr_of_def). by eexists. Qed.
Definition addr_of := addr_of_aux.(unseal).
Definition addr_of_eq : @addr_of = _ := addr_of_aux.(seal_eq).
Arguments addr_of : simpl never.
Notation "a &~ b" := (addr_of a b) (at level 30, no associativity).

Global Instance addr_of_persistent : Persistent (addr_of o l).
Proof. rewrite addr_of_eq. apply _. Qed.

Definition _at_def (base : Loc) (P : Rep) : mpred :=
  Exists a, base &~ a ** P a.
Definition _at_aux : seal (@_at_def). by eexists. Qed.
Definition _at := _at_aux.(unseal).
Definition _at_eq : @_at = _ := _at_aux.(seal_eq).

Global Instance _at_persistent : Persistent P -> Persistent (_at base P).
Proof. rewrite _at_eq. apply _. Qed.

Global Instance Proper__at_entails
  : Proper (eq ==> lentails ==> lentails) _at.
Proof.
  rewrite _at_eq. unfold _at_def. red. red. red.
  intros. simpl in *. subst. setoid_rewrite H0.
  reflexivity.
Qed.

Global Instance Proper__at_lequiv
  : Proper (eq ==> lequiv ==> lequiv) _at.
Proof.
  intros x y H1 ?? H2.
  rewrite _at_eq /_at_def. subst.
  setoid_rewrite H2.
  reflexivity.
Qed.


(** Values
 * These `Rep` predicates wrap `ptsto` facts
 *)
(* todo(gmm): make opaque *)
Definition pureR (P : mpred) : Rep :=
  as_Rep (fun _ => P).

Global Instance pureR_persistent (P : mpred) :
  Persistent P -> Persistent (pureR P).
Proof. intros. apply monPred_at_persistent_inv. apply  _. Qed.

(* this is the primitive *)
Definition primR_def {resolve:genv} (ty : type) q (v : val) : Rep :=
  as_Rep (fun addr => @tptsto _ resolve ty q (Vptr addr) v ** [| has_type v (drop_qualifiers ty) |]).
Definition primR_aux : seal (@primR_def). by eexists. Qed.
Definition primR := primR_aux.(unseal).
Definition primR_eq : @primR = _ := primR_aux.(seal_eq).
Arguments primR {resolve} ty q v : rename.

Global Instance primR_timeless resolve ty q p : Timeless (primR (resolve:=resolve) ty q p).
Proof. solve_Rep_timeless primR_eq. Qed.

Global Instance Proper_primR_entails
: Proper (genv_leq ==> (=) ==> (=) ==> (=) ==> lentails) (@primR).
Proof.
  do 5 red; intros; subst.
  rewrite primR_eq /primR_def. constructor; simpl.
  intros. setoid_rewrite H. reflexivity.
Qed.
Global Instance Proper_primR_equiv
: Proper (genv_eq ==> (=) ==> (=) ==> (=) ==> lequiv) (@primR).
Proof.
  do 5 red; intros; subst.
  rewrite primR_eq /primR_def. constructor; simpl.
  intros. setoid_rewrite H. reflexivity.
Qed.

Definition uninit_def {resolve:genv} (ty : type) q : Rep :=
  as_Rep (fun addr => Exists v : val, (primR (resolve:=resolve) ty q v) addr ).
(* todo(gmm): this isn't exactly correct, I need a Vundef *)
Definition uninit_aux : seal (@uninit_def). by eexists. Qed.
Definition uninitR := uninit_aux.(unseal).
Definition uninit_eq : @uninitR = _ := uninit_aux.(seal_eq).
Arguments uninitR {resolve} ty q : rename.

Global Instance uninit_timeless resolve ty q : Timeless (uninitR (resolve:=resolve) ty q).
Proof. solve_Rep_timeless uninit_eq. Qed.

(* this means "anything, including uninitialized" *)
Definition anyR_def {resolve} (ty : type) q : Rep :=
  as_Rep (fun addr => (Exists v, (primR (resolve:=resolve) ty q v) addr) \\//
       (uninitR (resolve:=resolve) ty q) addr).
Definition anyR_aux : seal (@anyR_def). by eexists. Qed.
Definition anyR := anyR_aux.(unseal).
Definition anyR_eq : @anyR = _ := anyR_aux.(seal_eq).
Arguments anyR {resolve} ty q : rename.

Global Instance anyR_timeless resolve ty q : Timeless (anyR (resolve:=resolve) ty q).
Proof. solve_Rep_timeless anyR_eq. Qed.

Definition tref_def (ty : type) (p : ptr) : Rep :=
  as_Rep (fun addr => [| addr = p |]).
Definition tref_aux : seal (@tref_def). by eexists. Qed.
Definition refR := tref_aux.(unseal).
Definition tref_eq : @refR = _ := tref_aux.(seal_eq).

Global Instance tref_timeless ty p : Timeless (refR ty p).
Proof. solve_Rep_timeless tref_eq. Qed.


(********************* DERIVED CONCEPTS ****************************)

Definition is_null_def : Rep :=
  as_Rep (fun addr => [| addr = nullptr |]).
Definition is_null_aux : seal (@is_null_def). by eexists. Qed.
Definition is_null := is_null_aux.(unseal).
Definition is_null_eq : @is_null = _ := is_null_aux.(seal_eq).

Global Instance is_null_persistent : Persistent (is_null).
Proof. solve_Rep_persistent is_null_eq. Qed.

Definition is_nonnull_def : Rep :=
  as_Rep (fun addr => [| addr <> nullptr |]).
Definition is_nonnull_aux : seal (@is_nonnull_def). by eexists. Qed.
Definition is_nonnull := is_nonnull_aux.(unseal).
Definition is_nonnull_eq : @is_nonnull = _ := is_nonnull_aux.(seal_eq).

Global Instance is_nonnull_persistent : Persistent (is_nonnull).
Proof. solve_Rep_persistent is_nonnull_eq. Qed.

Definition tlocal_at_def (r : region) (l : ident) (p : ptr) (v : Rep) : mpred :=
  local_addr r l p ** _at (_eq p) v.
Definition tlocal_at_aux : seal (@tlocal_at_def). by eexists. Qed.
Definition tlocal_at := tlocal_at_aux.(unseal).
Definition tlocal_at_eq : @tlocal_at = _ := tlocal_at_aux.(seal_eq).

Definition tlocal_def (r : region) (x : ident) (v : Rep) : mpred :=
  Exists a, tlocal_at r x a v.
Definition tlocal_aux : seal (@tlocal_def). by eexists. Qed.
Definition tlocal := tlocal_aux.(unseal).
Definition tlocal_eq : @tlocal = _ := tlocal_aux.(seal_eq).

(* this is for `Indirect` field references *)
Fixpoint path_to_Offset (resolve:genv) (from : globname) (final : ident)
         (ls : list (ident * globname))
: Offset :=
  match ls with
  | nil => @_field resolve {| f_type := from ; f_name := final |}
  | cons (i,c) ls =>
    _dot (@_field resolve {| f_type := from ; f_name := i |}) (path_to_Offset resolve c final ls)
  end.

Definition offset_for (resolve:genv) (cls : globname) (f : FieldOrBase) : Offset :=
  match f with
  | Base parent => _super resolve cls parent
  | Field i => _field resolve {| f_type := cls ; f_name := i |}
  | Indirect ls final =>
    path_to_Offset resolve cls final ls
  | This => _id
  end.

Global Opaque (* _local _global  *)_at _sub _field _offsetR _offsetL _dot primR (* tint tuint ptrR is_null is_nonnull *) addr_of.

End with_Σ.

Arguments addr_of : simpl never.
Notation "a &~ b" := (addr_of a b) (at level 30, no associativity).
Coercion pureR : mpred >-> Rep.

Global Opaque this_addr result_addr.

Arguments anyR {Σ resolve} ty q : rename.
Arguments uninitR {Σ resolve} ty q : rename.
Arguments primR {Σ resolve} ty q v : rename.
Arguments refR {Σ} ty v : rename.
Arguments _super {resolve} _ _ : rename.
Arguments _field {resolve} _ : rename.
Arguments _sub {resolve} _ : rename.
Arguments _global {resolve} _ : rename.
