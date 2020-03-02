(*
 * Copyright (C) BedRock Systems Inc. 2020 Gregory Malecha
 *
 * SPDX-License-Identifier:AGPL-3.0-or-later
 *)
Require Import bedrock.lang.cpp.ast.
Require Import bedrock.lang.cpp.logic.

Notation "'boolR' q v" := (@primR _ _ Tbool q%Qp (Vbool v)) (at level 30, q at level 1, v at level 1).

(* integers with implicit sizes *)
(* note(gmm): these might need to become definitions if we want to be generic
 * across sizes
 *)
Notation "'scharR' q v" := (@primR _ _ (Tchar W8 Signed) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'ucharR' q v" := (@primR _ _ (Tchar W8 Unsigned) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'charR' q v" := (ucharR q v) (at level 30, q at level 1, v at level 1).

Notation "'sshortR' q v" := (@primR _ _ (Tint W16 Signed) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'ushortR' q v" := (@primR _ _ (Tint W16 Unsigned) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'shortR' q v" := (sshortR q v) (at level 30, q at level 1, v at level 1).


Notation "'sintR' q v" := (@primR _ _ (Tint int_bits Signed) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'uintR' q v" := (@primR _ _ (Tint int_bits Unsigned) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'intR' q v" := (sintR q v) (at level 30, q at level 1, v at level 1).

Notation "'slongR' q v" := (@primR _ _ (Tint long_bits Signed) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'ulongR' q v" := (@primR _ _ (Tint long_bits Unsigned) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'longR' q v" := (slongR q v) (at level 30, q at level 1, v at level 1).

Notation "'slonglongR' q v" := (@primR _ _ (Tint W64 Signed) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'ulonglongR' q v" := (@primR _ _ (Tint W64 Unsigned) q%Qp (Vint v%Z)) (at level 30, q at level 1, v at level 1).
Notation "'longlongR' q v" := (slonglongR q v) (at level 30, q at level 1, v at level 1).

(* integers with explict sizes *)
Notation "'uint8' q v" := (ucharR q v) (at level 30, q at level 1, v at level 1).
Notation "'uint16' q v" := (ushortR q v) (at level 30, q at level 1, v at level 1).
Notation "'uint32' q v" := (uintR q v) (at level 30, q at level 1, v at level 1).
Notation "'uint64' q v" := (ulonglongR q v) (at level 30, q at level 1, v at level 1).

Notation "'int8' q v" := (scharR q v) (at level 30, q at level 1, v at level 1).
Notation "'int16' q v" := (shortR q v) (at level 30, q at level 1, v at level 1).
Notation "'int32' q v" := (intR q v) (at level 30, q at level 1, v at level 1).
Notation "'int64' q v" := (longlongR q v) (at level 30, q at level 1, v at level 1).




Notation "'ptrR<' ty '>' q p" := (@primR _ _ (Tpointer ty) q%Qp (Vptr p)) (at level 1, ty at level 20, q at level 1, p at level 1, format "'ptrR<' ty '>'  q  p").
Notation "'refR<' ty '>' p" := (@refR primR _ _ ty (Vptr p)) (at level 1, ty at level 200, p at level 1, format "'refR<' ty '>'  p").