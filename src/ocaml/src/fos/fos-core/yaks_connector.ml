open Yaks_ocaml
open Lwt.Infix
open Fos_errors




let global_actual_prefix = "/agfos"
let global_desired_prefix = "/dgfos"
let local_actual_prefix = "/alfos"
let local_desired_prefix = "/dlfos"


let default_system_id = "0"
let default_tenant_id = "0"

let create_path tokens =
  Yaks_types.Path.of_string @@ String.concat "/" tokens

let create_selector tokens =
  Yaks_types.Selector.of_string @@ String.concat "/" tokens


type state = {
  yaks_client : Yaks_api.t
; yaks_admin : Yaks.Admin.t
; ws : Yaks.Workspace.t
; listeners : string list
; evals : Yaks.Path.t list;
}

type connector = state Fos_core.MVar.t

let get_connector (config:Fos_core.configuration)=
  let loc = Apero.Option.get @@ Apero_net.Locator.of_string config.agent.yaks in
  let%lwt yclient = Yaks.login loc Apero.Properties.empty in
  let%lwt admin = Yaks.admin yclient in
  let%lwt ws = Yaks.workspace (create_path [global_actual_prefix; ""]) yclient in
  Lwt.return @@ Fos_core.MVar.create {  ws = ws
                                     ; yaks_client = yclient
                                     ; yaks_admin = admin
                                     ; listeners = []
                                     ; evals = []
                                     }

let close_connector y =
  Fos_core.MVar.guarded y @@ fun state ->
  Lwt_list.iter_p (fun e -> Yaks.Workspace.unsubscribe e state.ws) state.listeners
  >>= fun _ ->
  Lwt_list.iter_p (fun e -> Yaks.Workspace.unregister_eval e state.ws) state.evals
  >>= fun _ ->
  Yaks.logout state.yaks_client
  >>=  fun _ ->
  Fos_core.MVar.return () state
(*
  module F = sig

  .
  .
  .
  .
  end

module Make (sig prefix: string end):F

----

module Make(sig prefix:string end) = struct
  implementation
end

 *)

module MakeGAD(P: sig val prefix: string end) = struct

  let get_sys_info_path sysid =
    create_path [P.prefix; sysid; "info"]

  let get_sys_configuration_path sysid =
    create_path [P.prefix; sysid; "configuration"]

  let get_all_users_selector sysid =
    create_selector [P.prefix; sysid; "users"; "*"]

  let get_user_info_path sysid userid =
    create_path [P.prefix; sysid; "users"; userid; "info"]

  let get_all_tenants_selector sysid =
    create_selector [P.prefix; sysid; "tenants"; "*"]

  let get_tenant_info_path sysid tenantid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "info"]

  let get_tenant_configuration_path sysid tenantid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "configuration"]

  let get_all_nodes_selector sysid tenantid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "nodes"; "*"]

  let get_node_info_path sysid tenantid nodeid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "info"]

  let get_node_configuration_path sysid tenantid nodeid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "configuration"]

  let get_node_plugins_selector sysid tenantid nodeid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "plugins"; "*"]

  let get_node_plugins_subscriber_selector sysid tenantid nodeid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "plugins"; "**"]

  let get_node_plugin_info_path sysid tenantid nodeid pluginid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "plugins"; pluginid; "info"]

  let get_node_plugin_eval_path sysid tenantid nodeid pluginid func_name =
    create_path [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "plugins"; pluginid; "exec"; func_name]

  let get_node_fdu_info_path sysid tenantid nodeid fduid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "fdu"; fduid; "info"]

  let get_node_fdu_selector sysid tenantid nodeid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "nodes"; nodeid; "fdu"; "*"; "info"]

  let get_all_entities_selector sysid tenantid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "entities"; "*"]

  let get_all_networks_selector sysid tenantid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "networks"; "*"]

  let get_entity_info_path sysid tenantid entityid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "entities"; entityid; "info"]

  let get_network_info_path sysid tenantid networkid =
    create_path [P.prefix; sysid; "tenants"; tenantid; "networks"; networkid; "info"]

  let get_entity_all_instances_selector sysid tenantid entityid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "entities"; entityid; "instances"; "*"]

  let get_network_all_ports_selector sysid tenantid networkid =
    create_selector [P.prefix; sysid; "tenants"; tenantid; "networks"; networkid; "ports"; "*"]

  let get_entity_instance_info_path sysid tenantid entityid instanceid=
    create_path [P.prefix; sysid; "tenants"; tenantid; "entities"; entityid; "instances"; instanceid; "info"]

  let get_network_port_info_path sysid tenantid networkid portid=
    create_path [P.prefix; sysid; "tenants"; tenantid; "networks"; networkid; "ports"; portid; "info"]

  let extract_userid_from_path path =
    let ps = Yaks.Path.to_string path in
    List.nth (String.split_on_char '/' ps) 4

  let extract_tenantid_from_path path =
    let ps = Yaks.Path.to_string path in
    List.nth (String.split_on_char '/' ps) 4

  let extract_nodeid_from_path path =
    let ps = Yaks.Path.to_string path in
    List.nth (String.split_on_char '/' ps) 6

  let extract_pluginid_from_path path =
    let ps = Yaks.Path.to_string path in
    List.nth (String.split_on_char '/' ps) 8

  let get_sys_info sysid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = Yaks.Selector.of_path @@ get_sys_info_path sysid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_sys_info") ))
    | _ ->
      let _,v = (List.hd res) in
      try
        Lwt.return @@ Agent_types_j.system_info_of_string (Yaks.Value.to_string v)
      with
      | Atdgen_runtime.Oj_run.Error _ | Yojson.Json_error _  ->
        Lwt.fail @@ FException (`InternalError (`Msg ("Value is not well formatted in get_sys_info") ))
      | exn -> Lwt.fail exn

  let get_sys_config sysid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = Yaks.Selector.of_path @@ get_sys_configuration_path sysid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_sys_config") ))
    | _ ->
      let _,v = (List.hd res) in
      try
        Lwt.return @@ Agent_types_j.system_config_of_string (Yaks.Value.to_string v)
      with
      | Atdgen_runtime.Oj_run.Error _ | Yojson.Json_error _ ->
        Lwt.fail @@ FException (`InternalError (`Msg ("Value is not well formatted in get_sys_config") ))
      | exn -> Lwt.fail exn

  let get_all_users_ids sysid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = get_all_users_selector sysid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_all_users_ids") ))
    | _ ->
      Lwt.return @@ List.map (fun (k,_) -> extract_userid_from_path k) res

  let get_all_tenants_ids sysid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = get_all_tenants_selector sysid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_all_tenents_ids") ))
    | _ ->
      Lwt.return @@ List.map (fun (k,_) -> extract_tenantid_from_path k) res

  let get_all_nodes sysid tenantid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = get_all_nodes_selector sysid tenantid in
    Yaks.Workspace.get s  connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_all_nodes") ))
    | _ ->
      Lwt.return @@ List.map (fun (k,_) -> extract_nodeid_from_path k) res

  let get_node_info sysid tenantid nodeid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = Yaks.Selector.of_path @@ get_node_info_path sysid tenantid nodeid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_node_info") ))
    | _ ->
      let _,v = (List.hd res) in
      try
        Lwt.return @@ Agent_types_j.node_info_of_string (Yaks.Value.to_string v)
      with
      | Atdgen_runtime.Oj_run.Error _ | Yojson.Json_error _ ->
        Lwt.fail @@ FException (`InternalError (`Msg ("Value is not well formatted in get_node_info") ))
      | exn -> Lwt.fail exn

  let get_all_plugins_ids sysid tenantid nodeid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = get_node_plugins_selector sysid tenantid nodeid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_all_plugins_ids") ))
    | _ ->
      Lwt.return @@ List.map (fun (k,_) -> extract_pluginid_from_path k) res

  let get_plugin_info sysid tenantid nodeid pluginid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = Yaks.Selector.of_path @@ get_node_plugin_info_path sysid tenantid nodeid pluginid in
    Yaks.Workspace.get s connector.ws
    >>= fun res ->
    match res with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Empty value list on get_plugin_info") ))
    | _ ->
      let _,v = (List.hd res) in
      try
        Lwt.return @@ Agent_types_j.plugin_type_of_string (Yaks.Value.to_string v)
      with
      | Atdgen_runtime.Oj_run.Error _ | Yojson.Json_error _ ->
        Lwt.fail @@ FException (`InternalError (`Msg ("Value is not well formatted in get_plugin_info") ))
      | exn -> Lwt.fail exn

  let add_node_info sysid tenantid nodeid nodeinfo connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_info_path sysid tenantid nodeid in
    let value = Yaks.Value.StringValue (Types_j.string_of_node_info nodeinfo )in
    Yaks.Workspace.put p value connector.ws

  let add_node_configuration sysid tenantid nodeid nodeconf connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_configuration_path sysid tenantid nodeid in
    let value = Yaks.Value.StringValue (Agent_types_j.string_of_configuration nodeconf )in
    Yaks.Workspace.put p value connector.ws

  let add_node_plugin sysid tenantid nodeid (plugininfo:Types_t.plugin) connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_plugin_info_path sysid tenantid nodeid plugininfo.uuid  in
    let value = Yaks.Value.StringValue (Types_j.string_of_plugin plugininfo) in
    Yaks.Workspace.put p value connector.ws

  let observe_node_plugins sysid tenantid nodeid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = get_node_plugins_subscriber_selector sysid tenantid nodeid in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.plugin_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}


  let add_plugin_eval sysid tenantid nodeid pluginid func_name func connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let p = get_node_plugin_eval_path sysid tenantid nodeid pluginid func_name in
    let cb _ props =
      Lwt.return @@ Yaks.Value.StringValue (func props)
    in
    let%lwt _ = Yaks.Workspace.register_eval p cb connector.ws in
    let ls = List.append connector.evals [p] in
    Fos_core.MVar.return Lwt.return_unit {connector with evals = ls}

  let observe_node_fdu sysid tenantid nodeid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = get_node_fdu_selector sysid tenantid nodeid in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.atomic_entity_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}

  let add_node_fdu sysid tenantid nodeid fduid fduinfo connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_fdu_info_path sysid tenantid nodeid fduid in
    let value = Yaks.Value.StringValue (Types_j.string_of_atomic_entity fduinfo) in
    Yaks.Workspace.put p value connector.ws
end


module MakeLAD(P: sig val prefix: string end) = struct
  let get_node_info_path nodeid =
    create_path [P.prefix; nodeid; "info"]

  let get_node_configuration_path nodeid =
    create_path [P.prefix; nodeid; "configuration"]

  let get_node_plugins_selector nodeid =
    create_selector [P.prefix; nodeid; "plugins"; "*"; "info"]

  let get_node_plugins_subscriber_selector nodeid =
    create_selector [P.prefix; nodeid; "plugins"; "**"]

  let get_node_plugin_info_path nodeid pluginid=
    create_path [P.prefix; nodeid; "plugins"; pluginid; "info"]

  let get_node_runtimes_selector nodeid =
    create_selector [P.prefix; nodeid; "runtimes"; "*"]

  let get_node_network_managers_selector nodeid =
    create_selector [P.prefix; nodeid; "network_managers"; "*"]

  let get_node_runtime_fdus_selector nodeid pluginid =
    create_selector [P.prefix; nodeid; "runtimes"; pluginid; "fdu"; "*"; "info"]

  let get_node_fdus_selector nodeid =
    create_selector [P.prefix; nodeid; "runtimes"; "*"; "fdu"; "*"; "info"]

  let get_node_runtime_fdu_atomic_entitiy_selector nodeid pluginid fduid =
    create_selector [P.prefix; nodeid; "runtimes"; pluginid; "fdu"; fduid; "atomic_entity"; "*"]

  let get_node_networks_selector nodeid pluginid =
    create_selector [P.prefix; nodeid; "network_managers"; pluginid; "networks"; "*"]

  let get_node_network_ports_selector nodeid pluginid networkid =
    create_selector [P.prefix; nodeid; "network_managers"; pluginid; "networks"; networkid; "ports"; "*"]

  let get_node_fdu_info_path nodeid pluginid fduid=
    create_path [P.prefix; nodeid; "runtimes"; pluginid; "fdu"; fduid; "info"]

  let get_node_fdu_atomic_entity_info_path nodeid pluginid fduid atomicid =
    create_path [P.prefix; nodeid; "runtimes"; pluginid; "fdu"; fduid; "atomic_entity"; atomicid; "info"]

  let get_node_network_info_path nodeid pluginid networkid =
    create_path [P.prefix; nodeid; "network_managers"; pluginid;"networks"; networkid; "info"]

  let get_node_network_port_info_path nodeid pluginid networkid portid =
    create_path [P.prefix; nodeid; "network_managers"; pluginid;"networks"; networkid; "ports"; portid; "info"]

  let get_node_os_exec_path nodeid func_name =
    create_path [P.prefix; nodeid; "os"; "exec"; func_name]

  let get_node_plugin_eval_path nodeid pluginid func_name =
    create_path [P.prefix; nodeid; "plugins"; pluginid; "exec"; func_name ]

  let extract_pluginid_from_path path =
    let ps = Yaks.Path.to_string path in
    List.nth (String.split_on_char '/' ps) 4

  let add_os_eval nodeid func_name func connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let p = get_node_os_exec_path nodeid func_name in
    let cb _ props =
      let r = func props in
      Lwt.return @@ Yaks.Value.StringValue r
    in
    let%lwt _ = Yaks.Workspace.register_eval p cb connector.ws in
    let ls = List.append connector.evals [p] in
    Fos_core.MVar.return Lwt.return_unit {connector with evals = ls}

  let add_plugin_eval nodeid pluginid func_name func connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let p = get_node_plugin_eval_path nodeid pluginid func_name in
    let cb _ props =
      Lwt.return @@ Yaks.Value.StringValue (func props)
    in
    let%lwt _ = Yaks.Workspace.register_eval p cb connector.ws in
    let ls = List.append connector.evals [p] in
    Fos_core.MVar.return Lwt.return_unit {connector with evals = ls}


  let observe_node_plugins nodeid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = get_node_plugins_subscriber_selector nodeid in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.plugin_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}


  let observe_node_plugin nodeid pluginid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = Yaks.Selector.of_path @@ get_node_plugin_info_path nodeid pluginid in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.plugin_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}

  let observe_node_info nodeid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = Yaks.Selector.of_path @@ get_node_info_path nodeid  in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.node_info_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}

  let add_node_plugin nodeid (plugininfo:Types_t.plugin) connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_plugin_info_path nodeid plugininfo.uuid in
    let value = Yaks.Value.StringValue (Types_j.string_of_plugin plugininfo) in
    Yaks.Workspace.put p value connector.ws

  let get_node_plugin nodeid pluginid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = Yaks.Selector.of_path @@ get_node_plugin_info_path nodeid pluginid in
    let%lwt data = Yaks.Workspace.get s connector.ws in
    match data with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("get_node_plugin received empty data!!") ))
    | _ ->
      let _,v = List.hd data in
      Lwt.return @@ Types_j.plugin_of_string (Yaks.Value.to_string v)

  let get_node_plugins nodeid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let s = get_node_plugins_selector nodeid in
    let%lwt data = Yaks.Workspace.get s connector.ws in
    match data with
    | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("get_node_plugin received empty data!!") ))
    | _ ->  Lwt_list.map_p (fun (k,_ )-> Lwt.return @@ extract_pluginid_from_path k) data

  let remove_node_plugin nodeid pluginid connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_plugin_info_path nodeid pluginid in
    Yaks.Workspace.remove p connector.ws

  let add_node_info nodeid nodeinfo connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_info_path  nodeid in
    let value = Yaks.Value.StringValue (Agent_types_j.string_of_node_info nodeinfo )in
    Yaks.Workspace.put p value connector.ws

  let add_node_configuration nodeid nodeconf connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_configuration_path nodeid in
    let value = Yaks.Value.StringValue (Agent_types_j.string_of_configuration nodeconf )in
    Yaks.Workspace.put p value connector.ws

  let observe_node_runtime_fdu nodeid pluginid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = get_node_runtime_fdus_selector nodeid pluginid in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.atomic_entity_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}

  let observe_node_fdu nodeid callback connector =
    Fos_core.MVar.guarded connector @@ fun connector ->
    let s = get_node_fdus_selector nodeid in
    let cb data =
      match data with
      | [] -> Lwt.fail @@ FException (`InternalError (`Msg ("Listener received empty data!!") ))
      | _ ->
        let _,v = List.hd data in
        callback @@ Types_j.atomic_entity_of_string (Yaks.Value.to_string v)
    in
    let%lwt subid = Yaks.Workspace.subscribe ~listener:cb s connector.ws in
    let ls = List.append connector.listeners [subid] in
    Fos_core.MVar.return subid {connector with listeners = ls}

  let add_node_fdu nodeid pluginid fduid fduinfo connector =
    Fos_core.MVar.read connector >>= fun connector ->
    let p = get_node_fdu_info_path nodeid pluginid fduid in
    let value = Yaks.Value.StringValue (Types_j.string_of_atomic_entity fduinfo) in
    Yaks.Workspace.put p value connector.ws
end

module Global = struct

  module Actual = MakeGAD(struct let prefix = global_actual_prefix end)
  module Desired = MakeGAD(struct let prefix = global_desired_prefix end)


end

module Local = struct

  module Actual = MakeLAD(struct let prefix = local_actual_prefix end)
  module Desired = MakeLAD(struct let prefix = local_desired_prefix end)

end