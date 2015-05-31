(** Context: verification of cryptographic protocols using formal methods
    Goals: 1. define -in a nice way- the term algebra used to model messages
             exchanged by protocols.
             -> Basically a \Sigma-algebra equipped with an equational theory
                NOT necessarily convergent (e.g., xor is assoc+comm).
           2. define the notion of *static equivalence* (crucial in security)
              -> Basically a symetric predicate over sequences S1 S2 of terms
                 saying that S1 S2 have same length and we cannot build two
                 terms M M' whose atoms are positions in S1 such that
                 M S1 = M S1 but M S2 \neq M' S2 (modulo the equational theory).
           3. prove some static equivalences and non-equivalences 
           4. see what can be automatized using tactics. *)                 

(**  ======= Σ-ALGEBRA ========
Definition of a specific \Sigma-algebra (Σ = {hash/1;xor/2}):
   Var : countably many variables
   Name : countably many names (intuitively terms that look random and not
          known from the attacker)
   Const : countably many constants (on paper function symbols of arity 0)
           (intuitively terms that are publicly known)
   N : neutral of xor (same as above)
   Xor : intuitively eXclusive OR on bistrings
   Hash : basically a one-way function *)
Require Import Setoid Morphisms.

(* [NOTE] ici il faut faire un choix entre un ensemble de constante fini ou
   infini. Dans le cas fini, le plus propre serait de définir un
    Inductive cst := blank | ok.
   et l'utiliser dans term. Je garde les nat car *)
Definition cst := nat.          (* moralement csts. 1,2,3 ... *)
Definition var := nat.
Definition name := nat.
Inductive term :=
  | Var : var -> term
  | Name : name -> term
  | Const : cst -> term
  | Hash : term -> term
  | Xor : term -> term -> term
  | N : term.
(* Notations *)
Infix "xor" := Xor (at level 70).
Notation "'h' X" := (Hash X) (at level 60).
(* Some keys *)
Notation "'k'" := (Name 0).
Notation "'k1'" := (Name 1).
Notation "'k2'" := (Name 2).
(* Some nonces (Number ONCE ~ random values) *)
Notation "'n'" := (Name 3).
Notation "'n1'" := (Name 4).
Notation "'n2'" := (Name 5).
(* Some constants  *)
Notation "'ok'" := (Const 1).
Notation "'no'" := (Const 2).
Notation "'error'" := (Const 3).
Notation "'blank'" := (Const 0).  (* garbage (for later) *)

(**
Equations from which the equational theory will be defined.
(On paper, equations is a finite relation over terms without names.) *)
Inductive EqualE : term -> term -> Prop :=
| xorAssoc : forall t1 t2 t3: term, EqualE ((t1 xor t2) xor t3) (t1 xor (t2 xor t3))
| xorComm : forall t1 t2: term, EqualE (t1 xor t2) (t2 xor t1)
| xorI : forall t, EqualE (t xor N) t
| xorN : forall t, EqualE (t xor t) N.

(**
The main equivalence relation =E we build on EqualE is (on paper):
the least equivalence relation containing EqualE that is stable by application
of a constructor (ui =E vi implies f (ui ) =E f (vi) for any f ∈ Σ) and stable by substitution
(i.e., u =E v implies uσ =E vσ for any substitution σ = {t\x} for some variable x and term t). *)
Inductive EqE : term -> term -> Prop :=
| Base : forall t1 t2, EqualE t1 t2 -> EqE t1 t2
| EHash : Proper (EqE ==> EqE) Hash
| EXor : Proper (EqE ==> EqE ==> EqE) Xor
| Trans : forall t1 t2 t3, EqE t1 t2 -> EqE t2 t3 -> EqE t1 t3
| Refl : forall t, EqE t t
| Sym : forall t1 t2, EqE t1 t2 -> EqE t2 t1.
(* <HINTS> We help Coq to understand how to deal with rewrite on EqE. *)
Existing Instance EHash.
Existing Instance EXor.
Instance EqE_todo : subrelation EqualE EqE.
Proof. constructor;auto. Qed.
Instance EqE_equivalence: Equivalence EqE.
Proof. constructor.
intro;apply Refl.
intro; apply Sym.
intro;apply Trans.
Qed.

Infix "==E" := EqualE (at level 80).
Infix "=E" := EqE (at level 81).

(* Small example *)
Lemma ex1 : ((Var 3 xor h(Var 6)) xor h(Var 6)) =E (Var 3).
  transitivity  (Var 3 xor (h(Var 6) xor h(Var 6))).
  rewrite xorAssoc;reflexivity.
  rewrite (xorN).
  rewrite xorI. reflexivity.
Qed.


(** ====== STATIC EQUIVALENCE =======
We define what a frame is. On paper a frame is a substitution from (preserved and fresh)
'handles' (like variables) to terms. Handles are kinds of pointers to positions in the frame.
Intuitively, handles are used for referring to previously output terms.
On paper, we would define recipes on frames that are terms whose atoms are handles 
(positions in the frame) plus subsitution [recipe frame] gives a term.
Here, we use (nat -> term) for frames (positions to terms) and define a predicate 
[subR frame recipe term] saying that [recipe frame] gives [term]. Our recipes are
terms but subR interpret [Var n] as positions [n]. *)
Definition frame := nat -> term.
Inductive subR : frame -> term -> term -> Prop :=
| Atom : forall f : frame, forall atom:nat,
           subR f (Var atom) (f atom)
| SConst : forall f i, subR f (Const i) (Const i)
| SHash : forall f t1 t2, subR f t1 t2 -> subR f (h t1) (h t2) 
| SXor : forall f t11 t12 t21 t22, 
           subR f t11 t12 -> 
           subR f t21 t22 -> 
           subR f (t11 xor t21) (t12 xor t22).

(**
We now turns to the main property we would like to prove for some frames: static equivalence.
 *)
Definition EqS (f1 f2 : frame) : Prop :=
          (forall m1 m2, forall f1t1 f1t2 f2t1 f2t2,
             subR f1 m1 f1t1 ->        (* [m1 f1 =E f1t1] *)
             subR f1 m2 f1t2 ->        (* [m2 f1 =E f1t2] *)
             subR f2 m1 f2t1 ->        (* [m1 f2 =E f2t1] *)
             subR f2 m2 f2t2 ->        (* [m2 f2 =E f2t2] *)
             ((f1t1 =E f1t2) <-> (f2t1 =E f2t2))). (* [m1 f1 =E m2 f1 <-> m1 f2 =E m2 f2] *)

Infix "~~" := EqS (at level 80).

Lemma EqS_sym : forall f1 f2, EqS f1 f2 -> EqS f2 f1.
Proof.
  admit.                        (* TODO *)
Admitted.

(* Let's see examples of static equ. *)
Load data.
(* frame1 = {k1}
   frame1 = {k2}  *)
Definition NeS (f1 f2 : frame) :=
  (forall m, forall f1t1 f2t1,
     subR f1 m f1t1 ->        (* [m1 f1 =E f1t1] *)
     subR f2 m f2t1 ->        (* [m1 f2 =E f2t1] *)
     ((f1t1 =E N) <-> (f2t1 =E N))). (* [m1 f1 =E m2 f1 <-> m1 f2 =E m2 f2] *)
Lemma ex2_b : NeS frame1 frame2.
Proof.
induction m.
- (* VAR *)
  intros; split. intros H1.
  assert (H3: v=0 \/ not (v=0)) by admit;destruct H3 as [Hb | Hnb].
  rewrite Hb in *.
  inversion H;simpl in *.
  inversion H0;simpl in *.
  rewrite <-H3 in *.
  rewrite <-H6 in *.
  clear H2 H3 H4 f0 atom0 H5 H6 H7 atom f Hb.
  Print EqE.
  inversion H1.
  inversion H2.
  (* je pars dans une boucle à cause de la transitivité: induction sur les pas inductifs ....
      MASSE DE CHOSES relous *)
  inversion H1.
  unfold EqE in *.  
- (* Name *)    (* facile *)
- (* Hash *)
- (* Cst *)


Lemma ex2: frame1 ~~ frame2.    (* very easy one *)
Proof.
  do 6 intro; intros S11 S12 S21 S22.
  split; intro Eq.
  induction m1.
  - (* VAR *)
    assert (H: v=0 \/ not (v=0)) by admit;destruct H as [Hb | Hnb].
    + (* VAR 0 =ki *)
      rewrite Hb in *.
      inversion S11.
      simpl in *.
      rewrite <-H0 in Eq.
      clear f atom H H1 Hb H0.
      (* ICI on veut f1t2 sous une forme 'normale' = k1.
         Induction sur m2 sous une forme 'normale': Const, hash -> absurde.
         xor: montrer le lemme décrit plus bas -> absurde
         Var n ->  n=1. Et tout va bien de l'autre côté. *)
      admit.
    + assert (f1t1 = blank) by admit. (* devrait être OK *)
      rewrite H in *.
      admit. (* ici on fait comme dans le cas Var 0: 1. xor hash impossible
                2. cas Const -> OK mais alors du côté f2 aussi
                3. cas Var v: v=0 contredit Eq, v<>0 -> OK côté f2 aussi  *)
  - (* NAME *)
    inversion S11.              (* impossible (vient du fait que l'on a surchargé recettes et messages *)
  - (* CONST *)
    assert (c<>0) by admit.      (* le cas blank par un lemme? *)
    assert (Const c <> blank) by admit.   
    assert (H2: f1t1 = Const c) by admit; rewrite H2 in *; clear H2.
    assert (H2: f2t1 = Const c) by admit; rewrite H2 in *; clear H2.
    (* Ici encore j'ai envie de dire que Eq => f1t2 pris dans sa forme 'normale' est = Const c.
       S12 => *)
    admit.

Lemma ex2: f1 ~~ f2.
Proof.
  apply eqS.
  do 6 intro. intros S11 S12 S21 S22.
  split; intro Eq.                        (* TWO SYMETRIC CASES *)
  - 
(* Idea if the proof:
induction sur m1 (avec quantification sur tout le reste!): 
Je vais supposer que je peux toujours prendre des recettes sous une forme "normale" (attention ma théorie eq.
ne sera pas toujours orientable et convergente!). 
Ici une espèce de \xor_i (t_i) tel que t_i\neq t_j si i\neq j et t_i\neq xor(_,_).
On a aussi la prop cruciale: t ss cette forme avec i > 1 implique que
t \neq_E t' pour tout t' atomique (Var ou Name).
+ [m1 = Const i] => f1t1 = Const i
  ===> m2 = Const i (deux cas (m1 = blank ou pas))
  ======> f2t1 = f2t2 = Const i
+ [m1 = Name] => impossible de dériver S11 -> absurde
+ [m1 = Var atom] alors 4 cas selon que f1t1 = k1, h(k1 xor n1), ok ou blank
  détaillons le cas f1t1 = h(k1 xor n1). On a donc f1t2 =E = h(k1 xor n1)
  ==> On montre que [m2 = Var atom] en distinguant les cas sur m2 plus deux lemmes:
      L1: h(X) =E h(Y) -> x =E Y
      L2: not (exists m t, subR frame1 m t /\ t =E k1 xor n1)
+ [m1 = h(m1')] alors on distingue deux cas sur f1t1 qui est soit égal à h(k1 xor n2) soit pas.
  Si c'est le cas alors [m1' frame =E k1 xor n2] on montre que c'est absurde.
  Si ce n'est pas le cas alors m2 ne peut pas = Var i donc on peut montrer que m2 = h(m2') et
  on récure sur m1'.
+ [m1 = m11 xor m12]  => dans ce cas f1t1 est aussi un "vrai xor". m2 ne peut pas être un var car
  pas de xor dans frame1. De cette façon on a que m2 a la même structure XOR que m1 on se ramène donc
  aux atomes et hash déjà traités. 
 *)

Admitted.
