let ( >:: ), ( >::: ) = OUnit.(( >:: ), ( >::: ))

let ( =~ ) = OUnit.assert_equal
let printer_int_list xs =
  Format.asprintf "%a"
    (Format.pp_print_list Format.pp_print_int ~pp_sep:Format.pp_print_space)
    xs
let suites =
  __FILE__
  >::: [
         ( __LOC__ >:: fun _ ->
           OUnit.assert_equal
             (Ext_list.flat_map [1; 2] (fun x -> [x; x]))
             [1; 1; 2; 2] );
         ( __LOC__ >:: fun _ ->
           let ( =~ ) = OUnit.assert_equal ~printer:printer_int_list in
           Ext_list.flat_map [] (fun x -> [succ x]) =~ [];
           Ext_list.flat_map [1] (fun x -> [x; succ x]) =~ [1; 2];
           Ext_list.flat_map [1; 2] (fun x -> [x; succ x]) =~ [1; 2; 2; 3];
           Ext_list.flat_map [1; 2; 3] (fun x -> [x; succ x])
           =~ [1; 2; 2; 3; 3; 4] );
         ( __LOC__ >:: fun _ ->
           OUnit.assert_equal
             (Ext_list.stable_group [1; 2; 3; 4; 3] ( = ))
             [[1]; [2]; [4]; [3; 3]] );
         ( __LOC__ >:: fun _ ->
           let ( =~ ) = OUnit.assert_equal ~printer:printer_int_list in
           let f b _v = if b then 1 else 0 in
           Ext_list.map_last [] f =~ [];
           Ext_list.map_last [0] f =~ [1];
           Ext_list.map_last [0; 0] f =~ [0; 1];
           Ext_list.map_last [0; 0; 0] f =~ [0; 0; 1];
           Ext_list.map_last [0; 0; 0; 0] f =~ [0; 0; 0; 1];
           Ext_list.map_last [0; 0; 0; 0; 0] f =~ [0; 0; 0; 0; 1];
           Ext_list.map_last [0; 0; 0; 0; 0; 0] f =~ [0; 0; 0; 0; 0; 1];
           Ext_list.map_last [0; 0; 0; 0; 0; 0; 0] f =~ [0; 0; 0; 0; 0; 0; 1] );
         ( __LOC__ >:: fun _ ->
           OUnit.assert_equal
             (Ext_list.map_append [0; 1; 2] ["1"; "2"; "3"] (fun x ->
                  string_of_int x))
             ["0"; "1"; "2"; "1"; "2"; "3"] );
         ( __LOC__ >:: fun _ ->
           let a, b = Ext_list.split_at [1; 2; 3; 4; 5; 6] 3 in
           OUnit.assert_equal (a, b) ([1; 2; 3], [4; 5; 6]);
           OUnit.assert_equal (Ext_list.split_at [1] 1) ([1], []);
           OUnit.assert_equal (Ext_list.split_at [1; 2; 3] 2) ([1; 2], [3]) );
         ( __LOC__ >:: fun _ ->
           OUnit.assert_equal
             (Ext_list.assoc_by_int [(2, "x"); (3, "y"); (1, "z")] 1 None)
             "z" );
         ( __LOC__ >:: fun _ ->
           Ounit_tests_util.assert_raise_any (fun _ ->
               Ext_list.assoc_by_int [(2, "x"); (3, "y"); (1, "z")] 11 None) );
         ( __LOC__ >:: fun _ ->
           OUnit.assert_bool __LOC__
             (Ext_list.length_larger_than_n [1; 2] [1] 1);
           OUnit.assert_bool __LOC__
             (Ext_list.length_larger_than_n [1; 2] [1; 2] 0);
           OUnit.assert_bool __LOC__ (Ext_list.length_larger_than_n [1; 2] [] 2)
         );
         ( __LOC__ >:: fun _ ->
           OUnit.assert_bool __LOC__ (Ext_list.length_ge [1; 2; 3] 3);
           OUnit.assert_bool __LOC__ (Ext_list.length_ge [] 0);
           OUnit.assert_bool __LOC__ (not (Ext_list.length_ge [] 1)) );
       ]
