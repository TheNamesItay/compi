#use "pc.ml";;

exception X_not_yet_implemented;;
exception X_this_should_not_happen;;
  
type number =
  | Fraction of int * int
  | Float of float;;
  
type sexpr =
  | Bool of bool
  | Nil
  | Number of number
  | Char of char
  | String of string
  | Symbol of string
  | Pair of sexpr * sexpr;;

let rec sexpr_eq s1 s2 =
  match s1, s2 with
  | Bool(b1), Bool(b2) -> b1 = b2
  | Nil, Nil -> true
  | Number(Float f1), Number(Float f2) -> abs_float(f1 -. f2) < 0.001
  | Number(Fraction (n1, d1)), Number(Fraction (n2, d2)) -> n1 = n2 && d1 = d2
  | Char(c1), Char(c2) -> c1 = c2
  | String(s1), String(s2) -> s1 = s2
  | Symbol(s1), Symbol(s2) -> s1 = s2
  | Pair(car1, cdr1), Pair(car2, cdr2) -> (sexpr_eq car1 car2) && (sexpr_eq cdr1 cdr2);;
  
module Reader: sig
  val read_sexprs : string -> sexpr list
end
= struct

let nt_semicolon s = 
  let (s1, es1) = char ';' s in
  try let (s2, es2) = (caten (PC.star (const (fun s -> s != '\n'))) PC.nt_any) in
    ([], es2)
    with PC.X_no_match -> ([], []);;

let nt_semicolon_star = 
  PC.star nt_semicolon;;

let normalize_scheme_symbol str =
  let s = string_to_list str in
  if (andmap
	(fun ch -> (ch = (lowercase_ascii ch)))
	s) then str
  else Printf.sprintf "|%s|" str;;

let nt_sexp_comment =
  disj (PC.pack (PC.caten_list [(word ";#"); nt_sexp_comment; read_sexpr]) 
                (fun s -> [])
        PC.nt_epsilon

let word2 s = 
  PC.pack (PC.word s)
        (fun s -> [])  ;;             

let nt_space_or_comment = 
  PC.disj_list [PC.nt_whitespacent;_semicolon; nt_sexp_comment]

let nt_whitespace_star = 
  PC.plus PC.nt_whitespace;;

let nt_whitespace_plus = 
  PC.star PC.nt_whitespace;;

(* let nt_curly_par_open = PC.char '{';;
let nt_curly_par_close = PC.char '}';; *)
let nt_par_open = 
  let lp = char '(' in
  let spaced = caten (caten nt_whitespace_star lp) nt_whitespace_star in
  pack spaced (fun ((l, p), r) -> p);;

let nt_par_close = 
  let lp = char ')' in
  let spaced = caten (caten nt_whitespace_star lp) nt_whitespace_star in
  pack spaced (fun ((l, p), r) -> p);;
let nt_at = PC.char '@';;
let nt_plus_char = PC.char '+';;
let nt_minus_char = PC.char '-';;
let nt_plus_minus = PC.maybe (PC.disj nt_plus_char nt_minus_char);;

let nt_unquote = pack (PC.char '\,') (fun s -> Symbol("unquote"));;
let nt_quote_splice = pack (PC.word ",@") (fun s -> Symbol("unquote-splicing"));;
let nt_qquote = pack (PC.char '`') (fun s -> Symbol("quasiquote"));;
let nt_quote = pack (PC.char '\'') (fun s -> Symbol("quote"));;

let nt_bool_t = 
  PC.pack (word_ci "#t")
          (fun s -> Bool(true))
 
let nt_bool_f = 
  PC.pack (word_ci "#f")
          (fun s -> Bool(false))
    
let nt_bool = 
  PC.disj (nt_bool_t) nt_bool_f

let nt_backslash = char2 '\\';;

let nt_doublequote s = 
    let (e,es) = PC.char '\"' s in
      ('\"', es);;

let nt_2backslash s = 
    let (e,es) = PC.char '\\' s in
      ('\\', es);;

let nt_t s = 
    let (e,es) = PC.char_ci 't' s in
      ('\t', es);;

let nt_f s = 
    let (e,es) = PC.char_ci 'f' s in
      (char_of_int(12), es);;

let nt_n s = 
    let (e,es) = PC.char_ci 'n' s in
      ('\n', es);;

let nt_r s = 
    let (e,es) = PC.char 'r' s in
      ('\r', es);;

let nt_hashtag = char2 '#';;

let nt_char_prefix = 
  PC.caten nt_hashtag nt_backslash

let nt_meta_char s = 
  let (s1, es1) = nt_backslash s in 
  (PC.disj_list [nt_r; nt_f; nt_n; nt_t; nt_2backslash; nt_doublequote]) es1

let nt_visible_char = 
  PC.pack (PC.range '!' '~')
          (fun s -> Char(s))

let nt_named_newline s = 
  let (e,es) = PC.word_ci "newline" s in
      (Char(char_of_int(10)), es);;

let nt_named_nul s = 
  let (e,es) = PC.word_ci "nul" s in
      (Char(char_of_int(0)), es);;

let nt_named_return s = 
  let (e,es) = PC.word_ci "return" s in
      (Char(char_of_int(13)), es);;

let nt_named_tab s = 
  let (e,es) = PC.word_ci "tab" s in
      (Char(char_of_int(9)), es);;

let nt_named_formfeed s = 
  let (e,es) = PC.word_ci "page" s in
      (Char(char_of_int(12)), es);;

let nt_named_space s = 
  let (e,es) = PC.word_ci "space" s in
      (Char(char_of_int(32)), es);;

let nt_named_char = 
  PC.disj_list [nt_named_space; nt_named_tab; nt_named_return; nt_named_nul; nt_named_newline; nt_named_formfeed];;

let nt_char = 
  PC.caten (nt_char_prefix)
    (PC.disj (nt_named_char) (nt_visible_char));;

let nt_digit_0_to_9 =
  PC.range '0' '9' ;;

let nt_lowercase =
  PC.range 'a' 'z' ;;
                               
let nt_uppercase =
  PC.range 'A' 'Z' ;;

let nt_natural s =
  let (s, es) = PC.star (PC.pack 
                          (nt_digit_0_to_9) 
                          (fun s -> int_of_char(s) - int_of_char('0')))
                        s in
    ((List.fold_left 
      (fun acc curr -> acc*10+curr)
      0
      s),
      es
    );;

let nt_float_frac s =
  let (s, es) = PC.star (PC.pack 
                          (nt_digit_0_to_9) 
                          (fun s -> int_of_char(s) - int_of_char('0')))
                        s in
    ((List.fold_right 
      (fun curr acc -> acc*.0.1+.float_of_int(curr)*.0.1)
      s
      0.0),
      es);;

let nt_integer s =
  let (e, es) = nt_plus_minus (s) in
  (PC.pack (nt_natural)
    (function s -> match e with 
      | Some('-') -> -s
      | _ -> s))
    es;;

let nt_slash = PC.char '/';;

let nt_dot = 
  PC.char '.';;

let rec gcd a b =
        if b = 0 then a else gcd b (a mod b);;

let nt_number s =
  let (s1, es1) = nt_integer s in
  try let (s2, es2) = nt_slash es1 in
      let (s3, es3) = nt_natural es2 in
      let g = gcd s1 s3 in
      (Fraction((s1/g ,s3/g)), es3)
    with PC.X_no_match -> 
      try let (s2, es2) = nt_dot es1 in
          let (s3, es3) = nt_float_frac es2 in
          let (s4, es4) = nt_sci_e es3 in
          (Float((if s1 >= 0 then s3+.float_of_int(s1) else float_of_int(s1) - s3) * (10^s4)), es4)
      with PC.X_no_match ->
        let (s4, es4) = nt_sci_e es1 in
        if (s4 = 1) then (Fraction((s1,1)), es1)
                    else (Float((float_of_int(s1) *. (10^s4)), es4));;

(**used just for nums with e, returns (1,s) if found no e*)
let nt_int_or_float s = 
  try pack (caten (PC.char_ci 'e') nt_integer)
      (fun (e, pow) -> pow) s
    with PC.X_no_match -> (1, s)


let nt_string_literal =
  PC.const (fun s -> (s != (char_of_int 92) && s != (char_of_int 34)));;

let nt_string_char = 
  PC.disj (nt_string_literal) (nt_meta_char);;

let nt_string_doublequote = 
  char2 '\"';;

let nt_string s = 
  let (s1, es1) = nt_string_doublequote s in
  let (s2, es2) = PC.star (nt_string_char) es1 in
  let (s3, es3) = nt_string_doublequote es2 in
  (String(list_to_string(s2)), es3);;

let nt_no_dot_char = 
  PC.disj_list [nt_digit_0_to_9; nt_uppercase; nt_lowercase; (PC.one_of "!$^*-_=+<>?/:")];;

let nt_symbol_char =
  PC.disj (nt_no_dot_char) nt_dot;;

let nt_symbol =
  PC.pack
    (PC.disj (PC.pack (nt_no_dot_char)
                      (fun s -> [s]))
      (PC.pack (PC.caten (PC.pack (nt_symbol_char)
                      (fun s -> [s]))
        (PC.star nt_symbol_char))
        (fun (s1, s2) -> s1 @ s2)))
    (fun s -> String(list_to_string(s)));;

let tok_dot =
  let td = char '.' in
  let spaced = caten (caten nt_whitespace_star td) nt_whitespace_star in
  pack spaced (fun ((l, p), r) -> p);;

let nt_dot_list_end s = (* end of list from dot*)
  let rs = read_sexpr in
  let comb = caten (caten tok_dot rs) nt_par_close in
  pack comb (fun ((l, p), r) -> p);;

let rec nt_list s = 
  let (s1, es1) = nt_par_open s in
  try let (s2, es2) = nt_par_close es12 in
    (Nil, es2)
    with PC.X_no_match -> 
      let (s3, es3) = PC.star (read_sexpr) es12 in
      let (s4, es4) = (PC.disj (nt_dot_list_end)
                              pack (nt_par_close)
                              (fun s -> Nil)) es3 in
      (
        (
          List.fold_right
            (fun curr acc -> Pair(curr, acc))
            s3
            s4
        ),
        es4
      )

and nt_sign =
  (PC.disj_list [nt_qquote; nt_unquote_splice; nt_unquote; nt_quote])

and nt_signed_sexpr s = 
  let (s1, es1) = nt_sign s in
  PC.pack (read_sexpr es1)
          (fun s -> Pair(s1, Pair(s, Nil)))

and read_sexpr string = 
  (PC.pack (PC.caten 
          (nt_space)
          (PC.disj_list [
            nt_bool;
            nt_number;
            nt_symbol;
            nt_char;
            nt_signed_sexpr;
            nt_list
          ]))
        (fun (s, t) -> t)) string;;

let read_sexprs string = 
  (PC.pack
    (PC.caten (PC.star read_sexpr)
              (PC.caten (nt_space_or_comment) PC.nt_end_of_input))
    (fun (s,t) -> s)) string
  
end;; (* struct Reader *)