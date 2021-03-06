(* Copyright (c) 2019 by the Board of Trustees of the University of Iowa
   Licensed under the Apache License, Version 2.0 (the "License"); you
   may not use this file except in compliance with the License.  You
   may obtain a copy of the License at
   http://www.apache.org/licenses/LICENSE-2.0 
   Unless required by applicable law or agreed to in writing, software
   distributed under the License is distributed on an "AS IS" BASIS,
   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or
   implied. See the License for the specific language governing
   permissions and limitations under the License. 
*)

(** @author Andrew West *)
module A = VmtAst

type vmt_error = 
    | IdentifierAlreadyExists of Position.t * string
    | InvalidArgCount of Position.t * int * int
    | InvalidOperator of Position.t * string
    | InvalidType of Position.t * string
    | InvalidTypeWithOperator of Position.t * string * string
    | MissingAttribute of Position.t
    | MissingIdentifier of Position.t * string
    | MissingTerm of Position.t 
    | NonMatchingTypes of Position.t * string * string
    | NotSupported of Position.t * string

type vmt_type = 
    | BoolT
    | IntT
    | RealT
    | BitVecT of Numeral.t

let type_to_string _type =
    match _type with
    | BoolT -> "Bool"
    | IntT -> "Int"
    | RealT -> "Real"
    | BitVecT n -> "BitVec " ^ (Numeral.string_of_numeral n)

let filter_map (f : ('a -> 'b option)) (l : 'a list) : 'b list =
    l |> List.map f 
      |> List.filter (fun x -> match x with None -> false | _ -> true)
      |> List.map (fun x -> match x with Some v -> v | _ -> assert false)
    
let find_opt (func : ('a -> bool)) (lst: 'a list) : 'a option =
    try let ans = List.find func lst in Some ans
    with Not_found -> None

let rec compare_lists l ll = 
match (l,ll) with
| [], [] -> true
| [],_ -> false
| _,[] -> false
| (h::t), (hh::tt) -> if h = hh then compare_lists t tt
                      else false;;

let rec eval_sort sort sort_env =
    match sort with
    | A.AmbiguousType (pos, str) -> (
        let sort_exist = find_opt (fun x -> if fst x = str then true else false) sort_env in
        match sort_exist with
        | Some (id, type_list) -> Ok type_list
        | None -> Error ( InvalidType (pos, str))
    )
    | A.BoolType (_) -> Ok BoolT
    | A.RealType (_) -> Ok RealT
    | A.IntType (_) -> Ok IntT
    | A.BitVecType (pos, num_int) -> (
        let int = Numeral.to_int num_int in
        match int with 
        | 1 -> Ok (BitVecT num_int)
        | 8 -> Ok (BitVecT num_int)
        | 16 -> Ok (BitVecT num_int)
        | 32 -> Ok (BitVecT num_int)
        | 64 -> Ok (BitVecT num_int)
        | _ -> Error ( InvalidType (pos, ("BitVec " ^ (Numeral.string_of_numeral num_int)))) 
    )
    | A.MultiSort (pos, str, sort_list) -> Error (NotSupported (pos, "MutliSort")) (* TODO: Not currently supported becasue don't know how to handle it *)

and eval_sort_list sort_list sort_env=
    match sort_list with
    | [] -> None
    | sort :: t ->(
        match eval_sort sort sort_env with
        | Ok rt -> eval_sort_list t sort_env
        | Error error -> Some error
    )

let rec eval_sorted_var_list sorted_var_list local_env sort_env =
    match sorted_var_list with
    | [] -> Ok local_env
    | sorted_var :: tail -> (
        match sorted_var with
        | A.SortedVar (pos, ident, sort) -> (
            match (eval_sort sort sort_env) with
            | Error error -> Error error
            | Ok _type -> (
                let local_env' = (ident, _type) :: local_env in
                eval_sorted_var_list tail local_env' sort_env
            )
        )
    )

let rec check_attribute_list attribute_list term_type env pos =
    match attribute_list with
    | [] -> Error (MissingAttribute pos)
    | attribute :: [] -> (
        match attribute with
        | A.NextName (n_pos, n_ident)-> (
            match filter_map (fun x -> if fst x = n_ident then Some (snd x) else None) env with
            | [] -> (
                let env' = (n_ident, term_type) :: env in
                Ok (term_type, env')
            )
            | n_type :: _ -> if n_type = term_type then Ok (n_type, env) else Error (InvalidType (n_pos, type_to_string n_type))
        )
        | A.InitTrue p -> Ok (term_type, env)
        | A.TransTrue p -> Ok (term_type, env)
        | A.InvarProperty (p, int) -> Ok (term_type, env)
        | A.LiveProperty (p, int) -> Error (NotSupported (p, "LiveProperty"))
    )
    | attribute :: tail -> (
        match attribute with
        | A.NextName (n_pos, n_ident)-> (
            match filter_map (fun x -> if fst x = n_ident then Some (snd x) else None) env with
            | [] -> (
                let env' = (n_ident, term_type) :: env in
                Ok (term_type, env')
            )
            | n_type :: _ -> (
                if n_type = term_type 
                    then check_attribute_list tail term_type env pos
                    else Error (InvalidType (n_pos, type_to_string n_type))
            )
        )   
        | A.InitTrue p -> check_attribute_list tail term_type env pos
        | A.TransTrue p -> check_attribute_list tail term_type env pos 
        | A.InvarProperty (p, int) -> check_attribute_list tail term_type env pos
        | A.LiveProperty (p, int) -> Error (NotSupported (p, "LiveProperty"))
    )

let rec eval_term term env =
    match term with
    | A.Ident (pos, ident) -> (
        match filter_map (fun x -> if fst x = ident then Some (snd x) else None) env with
        | [] -> Error (MissingIdentifier (pos, ident))
        | var_type :: _ -> Ok (var_type, env)
    )
    | A.Integer (pos, int) -> Ok (IntT, env)
    | A.Real (pos, float) -> Ok (RealT, env)
    | A.True (pos) -> Ok (BoolT, env)
    | A.False (pos) -> Ok (BoolT, env)
    | A.BitVecConst (pos, _, int) -> Ok (BitVecT int, env)
    | A.ExtractOperation (pos, first, last, term) -> (
        match eval_term term env with
        | Ok (BitVecT size, env') -> (
            let extract_size = Numeral.add (Numeral.of_int 1) (Numeral.sub last first) in
            if  extract_size > size 
            then Error ( NonMatchingTypes (pos, type_to_string (BitVecT size), type_to_string (BitVecT extract_size)))
            else Ok (BitVecT extract_size, env')
        )
        | Ok (_type, _) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "extract"))
        | error -> error 
    )
    | A.Operation (pos, op, term_list) -> (
        match eval_operation pos op term_list env with
        | Ok (res_type, env') -> Ok (res_type, env')
        | Error error -> Error error
    )
    | A.AttributeTerm (pos, term, attribute_list) -> (
        match eval_term term env with
        | Ok (term_type, _) -> (
            match check_attribute_list attribute_list term_type env pos with
            | Ok (res_type, env') -> Ok (res_type, env')
            | Error error -> Error error
        )
        | error -> error
    )
    | A.Let (pos, var_bind_list, term) -> (
        let eval_vb = 
            fun x -> 
                match x with 
                | A.VarBind (_, id, term') -> (
                    match eval_term term' env with
                    | Ok (_type, _) -> Ok (id,_type)
                    | Error error -> Error error
                )
        in
        let mapped_params = List.map eval_vb var_bind_list in
        match find_opt (fun x -> match x with | Error _ -> true | _ -> false) mapped_params with
        | Some (Error error) -> Error error
        | None -> (
            let env' =
                List.fold_left 
                    (fun acc x -> match x with Ok (id, _type) -> (id,_type) :: acc | _ -> assert false)
                    env
                    mapped_params
            in
            eval_term term env'
        )
        | _ -> assert false
    )

and eval_operation pos op term_list env = 
    let check_bv_oper_returns_bv _type env'= 
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT l -> Ok (BitVecT l, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvsdiv"))
    in
    match (op, eval_term_list term_list env pos) with
    | ("not", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len > 1 
            then Error (InvalidArgCount (pos, 1, len))
            else 
                match _type with
                | BoolT -> Ok (BoolT, env')
                | BitVecT n -> Ok (BitVecT n, env)
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op)) 
    )
    | ("or", Ok (BoolT, env')) -> Ok (BoolT, env')
    | ("or", Ok (BitVecT n, env')) -> Ok (BitVecT n, env')
    | ("or", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("and", Ok (BoolT, env')) -> Ok (BoolT, env')
    | ("and", Ok (BitVecT n, env')) -> Ok (BitVecT n, env')
    | ("and", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("xor", Ok (BoolT, env')) -> Ok (BoolT, env')
    | ("xor", Ok (BitVecT n, env')) -> Ok (BitVecT n, env')
    | ("xor", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("to_real", Ok (_type, env')) when _type = IntT -> Ok (RealT, env')
    | ("to_real", Ok (_type, env')) when _type = RealT -> Ok (RealT, env')
    | ("to_real", Ok (BitVecT _, env')) -> Ok (RealT, env')
    | ("to_real", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("to_int", Ok (_type, env')) when _type = IntT -> Ok (IntT, env')
    | ("to_int", Ok (_type, env')) when _type = RealT -> Ok (IntT, env')
    | ("to_int", Ok (BitVecT _, env')) -> Ok (IntT, env')
    | ("to_int", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("is_int", Ok (_type, env')) when _type = IntT -> Ok (BoolT, env')
    | ("is_int", Ok (_type, env')) when _type = RealT -> Ok (BoolT, env')
    | ("is_int", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("=", Ok (_type, env')) when _type = BoolT -> Ok (_type, env')
    | ("=", Ok (_type, env')) when _type = IntT -> Ok (BoolT, env')
    | ("=", Ok (_type, env')) when _type = RealT -> Ok (BoolT, env')
    | ("=", Ok (BitVecT _, env')) -> Ok (BoolT, env')
    | ("=", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("<=", Ok (_type, env')) when _type = IntT -> Ok (BoolT, env')
    | ("<=", Ok (_type, env')) when _type = RealT -> Ok (BoolT, env')
    | ("<=", Ok (BitVecT _, env'))-> Ok (BoolT, env')
    | ("<=", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("<", Ok (_type, env')) when _type = IntT -> Ok (BoolT, env')
    | ("<", Ok (_type, env')) when _type = RealT -> Ok (BoolT, env')
    | ("<", Ok (BitVecT _, env'))-> Ok (BoolT, env')
    | ("<", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | (">=", Ok (_type, env')) when _type = IntT -> Ok (BoolT, env')
    | (">=", Ok (_type, env')) when _type = RealT -> Ok (BoolT, env')
    | (">=", Ok (BitVecT _, env')) -> Ok (BoolT, env')
    | (">=", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | (">", Ok (_type, env')) when _type = IntT -> Ok (BoolT, env')
    | (">", Ok (_type, env')) when _type = RealT -> Ok (BoolT, env')
    | (">", Ok (BitVecT _, env'))-> Ok (BoolT, env')
    | (">", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("-", Ok (_type, env')) when _type = IntT -> Ok (_type, env')
    | ("-", Ok (_type, env')) when _type = RealT -> Ok (_type, env')
    | ("-", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("+", Ok (_type, env')) when _type = IntT -> Ok (_type, env')
    | ("+", Ok (_type, env')) when _type = RealT -> Ok (_type, env')
    | ("+", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("*", Ok (_type, env')) when _type = IntT -> Ok (_type, env')
    | ("*", Ok (_type, env')) when _type = RealT -> Ok (_type, env')
    | ("*", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op)) 
    | ("//", Ok (_type, env')) when _type = IntT -> Ok (RealT, env')
    | ("//", Ok (_type, env')) when _type = RealT -> Ok (_type, env')
    | ("//", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op)) 
    | ("/", Ok (_type, env')) when _type = IntT -> Ok (_type, env')
    | ("/", Ok (_type, env')) when _type = RealT -> Ok (IntT, env')
    | ("/", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op)) 
    | ("mod", Ok (_type, env')) when _type = IntT -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else Ok (IntT, env')
    )
    | ("mod", Ok (_type, _)) -> Error (InvalidTypeWithOperator (pos, type_to_string _type, op))
    | ("abs", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | IntT -> Ok (IntT, env')
                | RealT -> Ok (_type, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "abs"))
    )
    | ("bvnot", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT l -> Ok (BitVecT l, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvand", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvor", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvneg", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT l -> Ok (BitVecT l, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvadd", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvmul", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvudiv", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvurem", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvshl", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvlshr", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvult", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvnand", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvnor", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'

    | ("bvxor", _ ) -> Error (NotSupported (pos, "bvxor"))
    | ("bvxnor", _ ) -> Error (NotSupported (pos, "bvxnor"))
    | ("bvcomp", _ ) -> Error (NotSupported (pos, "bvcomp"))
    (*
        | ("bvxor", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
        | ("bvxnor", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
        | ("bvcomp", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    *)
    
    | ("bvsub", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvsdiv", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvsmod", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvashr", Ok (_type, env')) -> check_bv_oper_returns_bv _type env'
    | ("bvule", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvugt", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvuge", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvslt", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvsle", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvsgt", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | ("bvsge", Ok (_type, env')) -> (
        let len = List.length term_list in
        if len <> 2 
            then Error (InvalidArgCount (pos, 2, len))
            else 
                match _type with
                | BitVecT _ -> Ok (BoolT, env')
                | _ -> Error (InvalidTypeWithOperator (pos, type_to_string _type, "bvslt"))
    )
    | (op, Ok (_type, _)) -> Error (InvalidOperator (pos, op))
    | (_, Error error) -> Error error


and eval_term_list term_list env pos = 
    match term_list with
    | [] -> Error (MissingTerm pos)
    | term :: [] -> eval_term term env
    | term :: tail -> (
        let term_result = eval_term term env in
        let tail_result = eval_term_list tail env pos in
        match (term_result, tail_result) with
        | (Error error, _) -> Error error
        | (_, Error error) -> Error error
        | (Ok (term_type, _), Ok (list_type, _)) -> (
            if term_type = list_type 
                then Ok (term_type, env)
                else Error (NonMatchingTypes (pos, type_to_string term_type, type_to_string list_type))
        )
    )

let eval_expr expr env sort_env =
    match expr with
    | A.DeclareFun (pos, ident, sort_list, sort) -> (
        let id_exist = find_opt (fun x -> if fst x = ident then true else false) env in
        match (id_exist, eval_sort_list sort_list sort_env, eval_sort sort sort_env) with
        | (Some _, _, _) -> Error (IdentifierAlreadyExists (pos, ident))
        | (_, Some error, _) -> Error error
        | (_, _, Error error) -> Error error
        | (_, _, Ok return_type ) -> Ok (((ident, return_type) :: env), sort_env)
    )
    | A.DefineFun (pos, ident, sorted_var_list, sort, term) -> (
        let id_exist = find_opt (fun x -> if fst x = ident then true else false) env in
        match (id_exist, eval_sorted_var_list sorted_var_list env sort_env, eval_sort sort sort_env) with
        | (Some _, _, _) -> Error (IdentifierAlreadyExists (pos, ident))
        | (_, Error error, _) -> Error error
        | (_, _, Error error) -> Error error
        | (_, Ok local_env, Ok return_type) -> (
            match eval_term term local_env with
            | Ok (return_type', env') when return_type' = return_type -> Ok (((ident, return_type) :: env'), sort_env)
            | Ok (return_type', _ ) -> Error (InvalidType (pos, type_to_string return_type'))
            | Error error -> Error error
        )
    )
    | A.DefineSort (pos, ident, [], sort) -> (
        let id_exist = find_opt (fun x -> if fst x = ident then true else false) sort_env in
        match (id_exist, eval_sort sort sort_env) with
        | (Some _, _ ) -> Error (IdentifierAlreadyExists (pos, ident))
        | (_ , Error error) -> Error error
        | (_, Ok return_type) -> Ok (env, ((ident, return_type) :: sort_env))
    )
    | A.DefineSort (pos, ident, ident_list, sort) -> Error (NotSupported (pos, "DefineSort w/ Arguments"))
    (* TODO: determine what we need to check or if we even support declare sort, set logic, and set option*)
    | A.DeclareSort (pos, ident, num) -> Error (NotSupported (pos, "DeclareSort"))  
    | A.SetLogic (pos, ident) -> Error (NotSupported (pos, "SetLogic")) 
    | A.SetOption (pos, ident, att) -> Error (NotSupported (pos, "SetOption")) 
    | A.Assert (pos, term) -> (
        match eval_term term env with
        | Ok (BoolT, env') -> Ok (env', sort_env)
        | Ok (wrong_type, _) -> Error (InvalidType (pos, type_to_string wrong_type))
        | Error error -> Error error
    )

let rec evaluate_expr_list expr_list env sort_env = 
    match expr_list with
    | [] -> Ok expr_list
    | expr :: t -> (
        let res = eval_expr expr env sort_env in
        match res with
        | Ok (env', sort_env') -> evaluate_expr_list t env' sort_env'
        | Error error -> Error error
    )

let check_vmt (expr_list : A.t ) : (A.t, vmt_error) result = 
    match evaluate_expr_list expr_list [] [] with
    | Ok _ -> Ok expr_list
    | Error error -> Error error