(* This file is part of the Kind verifier

 * Copyright (c) 2007-2009 by the Board of Trustees of the University of Iowa, 
 * here after designated as the Copyright Holder.
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *     * Redistributions of source code must retain the above copyright
 *       notice, this list of conditions and the following disclaimer.
 *     * Redistributions in binary form must reproduce the above copyright
 *       notice, this list of conditions and the following disclaimer in the
 *       documentation and/or other materials provided with the distribution.
 *     * Neither the name of the University of Iowa, nor the
 *       names of its contributors may be used to endorse or promote products
 *       derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDER ''AS IS'' AND ANY
 * EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
 * WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER BE LIABLE FOR ANY
 * DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
 * (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
 * LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
 * ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
 * SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 *)

(* ********************************************************************** *)
(* Helper functions                                                       *)
(* ********************************************************************** *)

(* Pretty-print a list *)
let rec pp_print_list pp sep ppf = function 

  (* Output nothing for the empty list *) 
  | [] -> ()

  (* Output a single element in the list  *) 
  | e :: [] -> 
    pp ppf e

  (* Output a single element and a space *) 
  | e :: tl -> 

    (* Output one element *)
    pp_print_list pp sep ppf [e]; 

    (* Output separator *)
    Format.fprintf ppf sep; 

    (* Output the rest of the list *)
    pp_print_list pp sep ppf tl


(* Pretty-print a position *)
let pp_print_position 
    ppf 
    { Lexing.pos_fname; Lexing.pos_lnum; Lexing.pos_bol; Lexing.pos_cnum } =

  Format.fprintf 
    ppf
    "(%s,%d,%d)"
    pos_fname
    pos_lnum
    (pos_cnum - pos_bol)


(* ********************************************************************** *)
(* Type declarations                                                      *)
(* ********************************************************************** *)


(* An identifier *)
type id = string 


(* A Lustre expression *)
type expr =

  (* Identifier *)
  | Id of Lexing.position * id
  | RecordProject of Lexing.position * id * id
  | TupleProject of Lexing.position * expr * expr

  (* Values *)
  | True of Lexing.position
  | False of Lexing.position
  | Num of Lexing.position * id
  | Dec of Lexing.position * id

  (* List of expressions *)
  | ExprList of Lexing.position * expr list 

  (* Tuple expression *)
  | TupleExpr of Lexing.position * expr list 

  (* Array constructor of single expression *)
  | ArrayConstr of Lexing.position * expr * expr 

  (* Array constructor of single expression *)
  | ArraySlice of Lexing.position * expr * expr * expr

  (* Array constructor of single expression *)
  | ArrayConcat of Lexing.position * expr * expr

  (* Boolean operators *)
  | Not of Lexing.position * expr 
  | And of Lexing.position * expr * expr 
  | Or of Lexing.position * expr * expr
  | Xor of Lexing.position * expr * expr 
  | Impl of Lexing.position * expr * expr 
  | OneHot of Lexing.position * expr list

  (* Arithmetic operators *)
  | Uminus of Lexing.position * expr 
  | Mod of Lexing.position * expr * expr
  | Minus of Lexing.position * expr * expr
  | Plus of Lexing.position * expr * expr
  | Div of Lexing.position * expr * expr
  | Times of Lexing.position * expr * expr
  | Intdiv of Lexing.position * expr * expr

  (* If operator *)
  | Ite of Lexing.position * expr * expr * expr 

  (* Relations *)
  | Eq of Lexing.position * expr * expr 
  | Neq of Lexing.position * expr * expr
  | Lte of Lexing.position * expr * expr
  | Lt of Lexing.position * expr * expr
  | Gte of Lexing.position * expr * expr
  | Gt of Lexing.position * expr * expr

  (* Clock operators *)
  | When of Lexing.position * expr * expr 
  | Current of Lexing.position * expr
  | Condact of Lexing.position * expr * expr * expr list 
  
  (* Temporal operators *)
  | Pre of Lexing.position * expr 
  | Fby of Lexing.position * expr * int * expr 
  | Arrow of Lexing.position * expr * expr 

  (* A node call *)
  | Call of Lexing.position * id * expr list 


(* A built-in type *)
type lustre_type = 
  | Bool
  | Int
  | Real
  | UserType of id 
  | TupleType of lustre_type list
  | RecordType of typed_ident list
  | ArrayType of (lustre_type * expr)
  | EnumType of id list


(* A record field *)
and typed_ident = id * lustre_type

(* A declaration of a type *)
type type_decl = id * lustre_type  

(* A clock expression *)
type clock_expr =
  | ClockPos of id
  | ClockNeg of id
  | ClockTrue 


(* A declaration of a clocked type *)
type clocked_typed_decl = id * lustre_type * clock_expr


(* A declaration of a clocked type *)
type const_clocked_typed_decl = id * lustre_type * clock_expr * bool


(* A declaration of a constant *)
type const_decl = 
  | FreeConst of id * lustre_type
  | UntypedConst of id * expr 
  | TypedConst of id * expr * lustre_type


(* A variable declaration *)
type var_decl = id * lustre_type * clock_expr


(* A static parameter of a node *)
type node_param = 
  | TypeParam of id
  | ConstParam of (id * lustre_type)


(* A local declaration in a node *)
type node_local_decl =
  | NodeConstDecl of const_decl 
  | NodeVarDecl of var_decl


(* An equation or assertion in the node body *)
type node_equation =
  | Assert of expr
  | Equation of id list * expr 
  | AnnotMain
  | AnnotProperty of expr

(* A contract clause *)
type contract_clause =
  | Requires of expr
  | Ensures of expr

(* A contract as a list of clauses *)
type contract = contract_clause list 

(* A node declaration *)
type node_decl = id * node_param list * const_clocked_typed_decl list * clocked_typed_decl list * node_local_decl list * node_equation list * contract 
  

(* A function declaration *)
type func_decl = id * (id * lustre_type) list * (id * lustre_type) list
  

(* A declaration as parsed *)
type declaration = 
  | TypeDecl of type_decl
  | ConstDecl of const_decl
  | NodeDecl of node_decl
  | FuncDecl of func_decl


(* A Lustre program *)
type t = declaration list


(* ********************************************************************** *)
(* Pretty-printing functions                                              *)
(* ********************************************************************** *)

(* Pretty-print an identifier *)
let pp_print_ident = Format.pp_print_string

(* Pretty-print a Lustre expression *)
let rec pp_print_expr ppf = 

  let ppos ppf p =
    (if false then Format.fprintf else Format.ifprintf)
      ppf
      "%a" 
      pp_print_position p
  in

  (* Pretty-print a string *)
  let ps p = Format.fprintf ppf "%a%s" ppos p in 

  (* Pretty-print a unary operator *)
  let p1 p s e = 
    Format.fprintf ppf "@[<hv 2>%a(%s %a)@]" 
      ppos p 
      s 
      pp_print_expr e 
  in 

  (* Pretty-print a binary infix operator *)
  let p2 p s e1 e2 = 
    Format.fprintf ppf
      "@[<hv 2>%a(%a %s@ %a)@]" 
      ppos p 
      pp_print_expr e1 
      s 
      pp_print_expr e2 
  in 

  (* Pretty-print a ternary infix operator *)
  let p3 p s1 s2 s3 e1 e2 e3 = 
    Format.fprintf ppf
      "@[<hv 2>%a(%s@ %a@;<1 -1>%s@ %a@;<1 -1>%s@ %a)@]" 
      ppos p 
      s1 
      pp_print_expr e1 
      s2
      pp_print_expr e2 
      s3 
      pp_print_expr e3 
  in 
  
  (* Pretty-print a comma-separated list of expressions *)
  let rec pl ppf = function 
    | [] -> ()
    | [e] -> Format.fprintf ppf "%a" pp_print_expr e
    | e :: tl -> Format.fprintf ppf "%a,@ %a" pl [e] pl tl
  in

  (* Pretty-print a variadic prefix operator *)
  let pnp p s l = 
    Format.fprintf ppf
      "@[<hv 2>%a%s(%a)@]" 
      ppos p 
      s
      pl l
  in

  function
    
    | Id (p, id) -> ps p id
 
    | ExprList (p, l) -> Format.fprintf ppf "%a@[<hv 1>(%a)@]" ppos p pl l

    | TupleExpr (p, l) -> Format.fprintf ppf "%a@[<hv 1>[%a]@]" ppos p pl l

    | ArrayConstr (p, e1, e2) -> 

      Format.fprintf ppf 
        "%a@[<hv 1>[%a^%a]@]" 
        ppos p 
        pp_print_expr e1 
        pp_print_expr e2

    | ArraySlice (p, e, il, iu) -> 

      Format.fprintf ppf 
        "%a@[<hv 1>%a[%a..%a]@]" 
        ppos p 
        pp_print_expr e
        pp_print_expr il 
        pp_print_expr iu

    | ArrayConcat (p, e1, e2) -> 

      Format.fprintf ppf 
        "%a@[<hv 1>%a|%a@]" 
        ppos p 
        pp_print_expr e1
        pp_print_expr e2 

    | RecordProject (p, id, f) -> 
      Format.fprintf ppf "%a%s.%s" ppos p id f

    | TupleProject (p, e, f) -> 
      Format.fprintf ppf "%a%a[%a]" ppos p pp_print_expr e pp_print_expr f

    | True p -> ps p "true"
    | False p -> ps p "false"

    | Num (p, n) -> ps p n
    | Dec (p, d) -> ps p d

    | Not (p, e) -> p1 p "not" e
    | And (p, e1, e2) -> p2 p "and" e1 e2
    | Or (p, e1, e2) -> p2 p "or" e1 e2
    | Xor (p, e1, e2) -> p2 p "xor" e1 e2
    | Impl (p, e1, e2) -> p2 p "=>" e1 e2
    | OneHot (p, e) -> pnp p "#" e

    | Uminus (p, e) -> p1 p "-" e
    | Mod (p, e1, e2) -> p2 p "mod" e1 e2 
    | Minus (p, e1, e2) -> p2 p "-" e1 e2
    | Plus (p, e1, e2) -> p2 p "+" e1 e2
    | Div (p, e1, e2) -> p2 p "/" e1 e2
    | Times (p, e1, e2) -> p2 p "*" e1 e2
    | Intdiv (p, e1, e2) -> p2 p "div" e1 e2

    | Ite (p, e1, e2, e3) -> p3 p "if" "then" "else" e1 e2 e3

    | Eq (p, e1, e2) -> p2 p "=" e1 e2
    | Neq (p, e1, e2) -> p2 p "<>" e1 e2
    | Lte (p, e1, e2) -> p2 p "<=" e1 e2
    | Lt (p, e1, e2) -> p2 p "<" e1 e2
    | Gte (p, e1, e2) -> p2 p ">=" e1 e2
    | Gt (p, e1, e2) -> p2 p ">" e1 e2

    | When (p, e1, e2) -> p2 p "when" e1 e2
    | Current (p, e) -> p1 p "current" e
    | Condact (p, e1, e2, e3) -> pnp p "condact" (e1 :: e2 :: e3)
  
    | Pre (p, e) -> p1 p "pre" e
    | Fby (p, e1, i, e2) -> 

      Format.fprintf ppf 
        "%afby(p, %a,@ %d,@ %a)" 
        ppos p 
        pp_print_expr e1 
        i 
        pp_print_expr e2

    | Arrow (p, e1, e2) -> p2 p "->" e1 e2

    | Call (p, id, l) -> pnp p id l


(* Pretty-print a clock expression *)
let pp_print_clock_expr ppf = function

  | ClockPos s -> Format.fprintf ppf "@ when %a" pp_print_ident s
  | ClockNeg s -> Format.fprintf ppf "@ when not %a" pp_print_ident s
  | ClockTrue -> ()


(* Pretty-print a Lustre type *)
let rec pp_print_lustre_type ppf = function

  | Bool -> Format.fprintf ppf "bool"
  | Int -> Format.fprintf ppf "int"
  | Real -> Format.fprintf ppf "real"
  | UserType s -> Format.fprintf ppf "%s" s

  | TupleType l -> 

    Format.fprintf ppf 
      "@[<hv 1>[%a]@]" 
      (pp_print_list pp_print_lustre_type ",@ ") l

  | RecordType l -> 

    Format.fprintf ppf 
      "struct @[<hv 2>{ %a }@]" 
      (pp_print_list pp_print_typed_ident ";@ ") l

  | ArrayType (t, e) -> 

    Format.fprintf ppf 
      "%a^%a" 
      pp_print_lustre_type t 
      pp_print_expr e

  | EnumType l -> 

    Format.fprintf ppf 
      "enum @[<hv 2>{ %a }@]" 
      (pp_print_list Format.pp_print_string ",@ ") l


(* Pretty-print a typed identifier *)
and pp_print_typed_ident ppf (s, t) = 
  Format.fprintf ppf 
    "@[<hov 2>%a:@ %a@]" 
    pp_print_ident s 
    pp_print_lustre_type t


(* Pretty-print a typed identifier with a clock *)
and pp_print_clocked_typed_ident ppf (s, t, c) = 
  Format.fprintf ppf 
    "@[<hov 2>%a:@ %a%a@]" 
    pp_print_ident s 
    pp_print_lustre_type t 
    pp_print_clock_expr c


(* Pretty-print a typed identifier with a clock, possibly constant *)
and pp_print_const_clocked_typed_ident ppf (s, t, c, o) = 
  Format.fprintf ppf "@[<hov 2>%t%a:@ %a%a@]" 
    (function ppf -> if o then Format.fprintf ppf "const ")
    pp_print_ident s 
    pp_print_lustre_type t 
    pp_print_clock_expr c


(* Pretty-print a single static node parameter *)
let pp_print_node_param ppf = function

  | TypeParam t -> 

    Format.fprintf ppf "type %s" t

  | ConstParam (s, t) -> 

    Format.fprintf ppf "const %s : %a" s pp_print_lustre_type t


(* Pretty-print a list of static node parameters *)
let pp_print_node_param_list ppf = function 

  | [] -> ()

  | l -> 
    
    Format.fprintf ppf 
      "@[<hv 2><<%a>>@]" 
      (pp_print_list pp_print_node_param ";@ ") l


(* Pretty-print a variable declaration *)
let pp_print_var_decl ppf = function 

  | s, t, c -> 

    Format.fprintf ppf 
      "@[<hov 2>%a:@ %a%a;@]" 
      pp_print_ident s 
      pp_print_lustre_type t
      pp_print_clock_expr c


(* Pretty-print a constant declaration *)
let pp_print_const_decl ppf = function

  | FreeConst (s, t) -> 

    Format.fprintf ppf 
      "@[<hov 2>const %a:@ %a;@]" 
      pp_print_ident s 
      pp_print_lustre_type t

  | UntypedConst (s, e) -> 

    Format.fprintf ppf 
      "@[<hov 2>const %a =@ %a;@]" 
      pp_print_ident s 
      pp_print_expr e

  | TypedConst (s, e, t) -> 

    Format.fprintf ppf 
      "@[<hov 2>const %a:@ %a =@ %a;@]" 
      pp_print_ident s 
      pp_print_lustre_type t
      pp_print_expr e


(* Pretty-print a node-local variable declaration, skip others *)
let pp_print_node_local_decl_var ppf = function

  | NodeVarDecl v -> pp_print_var_decl ppf v

  | _ -> ()


(* Pretty-print a node-local constant declaration, skip others *)
let pp_print_node_local_decl_const ppf = function

  | NodeConstDecl c -> pp_print_const_decl ppf c

  | _ -> ()


(* Pretty-print a node-local declaration *)
let pp_print_node_local_decl ppf l = 

  let c, v = 
    List.partition (function NodeConstDecl _ -> true | _ -> false) l 
  in

  if c = [] then () else 

    Format.fprintf ppf 
      "@;<1 -2>%a" 
      (pp_print_list pp_print_node_local_decl_const "@;<1 -2>") c;

  if v = [] then () else 

    Format.fprintf ppf
      "@;<1 -2>var@ @[<hv 2>%a@]"
      (pp_print_list pp_print_node_local_decl_var "@ ") v 


(* Pretty-print a node equation *)
let pp_print_node_equation ppf = function

  | Assert e -> 

    Format.fprintf ppf "assert %a;" pp_print_expr e

  | Equation ([l], e) -> 
    
    Format.fprintf ppf 
      "@[<hv 2>%a =@ %a;@]" 
      pp_print_ident l
      pp_print_expr e

  | Equation (l, e) -> 
    
    Format.fprintf ppf 
      "@[<hv 2>@[<hv 1>(%a)@] =@ %a;@]" 
      (pp_print_list pp_print_ident ",@ ") l
      pp_print_expr e
                  
  | AnnotMain -> Format.fprintf ppf "--%%MAIN;"

  | AnnotProperty e -> Format.fprintf ppf "--%%PROPERTY %a;" pp_print_expr e 


(* Pretty-print a contract clause *)
let pp_print_contract_clause ppf = function 

  | Requires e -> 

    Format.fprintf ppf "--%@requires %a;" pp_print_expr e

  | Ensures e -> 

    Format.fprintf ppf "--%@ensures %a;" pp_print_expr e


(* Pretty-print a node contract *)
let pp_print_contract ppf c = 

  if c = [] then () else

    Format.fprintf ppf 
      "@[<v>%a@,@]" 
      (pp_print_list pp_print_contract_clause "@,") c
  

(* Pretty-print a declaration *)
let pp_print_declaration ppf = function

  | TypeDecl (s, t) -> 

    Format.fprintf ppf "type %s = %a;" s pp_print_lustre_type t

  | ConstDecl c -> pp_print_const_decl ppf c

  | NodeDecl (n, p, i, o, l, e, r) -> 

    Format.fprintf ppf
      "@[<hv 2>%anode %a@[<hv 2>%a@]@ \
       @[<hv 1>(%a)@]@;<1 -2>\
       returns@ @[<hv 1>(%a)@];\
       %a@;<1 -2>\
       @[<hv 2>let@ \
       %a@;<1 -2>\
       tel;@]@]" 
      pp_print_contract r
      pp_print_ident n 
      pp_print_node_param_list p
      (pp_print_list pp_print_const_clocked_typed_ident ";@ ") i
      (pp_print_list pp_print_clocked_typed_ident ";@ ") o
      pp_print_node_local_decl l
      (pp_print_list pp_print_node_equation "@ ") e 

  | FuncDecl (n, i, o) -> 

    Format.fprintf ppf
      "@[<hv 2>function %a@ \
       @[<hv 1>(%a)@]@;<1 -2>\
       returns@ @[<hv 1>(%a)@];@]" 
      pp_print_ident n 
      (pp_print_list pp_print_typed_ident ";@ ") i
      (pp_print_list pp_print_typed_ident ";@ ") o


(* 
   Local Variables:
   compile-command: "ocamlbuild -use-menhir -tag debug -tag annot test.native"
   indent-tabs-mode: nil
   End: 
*)
  
