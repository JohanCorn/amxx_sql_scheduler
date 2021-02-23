#include <amxmodx>
#include <amxmisc>
#include <sql_scheduler>

enum _:MANAGER_DATA {

	MD_NAME[64],
	MD_ADDRESS[64],
	MD_USERNAME[64],
	MD_PASSWORD[64],
	MD_DATABASE[64],
	Handle: MD_SQL
};

enum _: TYPE_DATA {

	TD_MANAGER_ID,
	TD_NAME[32]
}

new g_manager_file[128], g_query_file[128], g_plugin_end, g_forward_result, g_forward_query;
new Array: g_managers, Array: g_types, Array: g_queries, g_query_id, bool: g_query_send;
new Trie: g_manager_ids, Trie: g_type_ids, g_cv_log;

public plugin_precache() {

	get_configsdir(g_manager_file, charsmax(g_manager_file));
	format(g_manager_file, charsmax(g_manager_file), "%s/%s", g_manager_file, "managers.ini");

	if ( !file_exists(g_manager_file) )
		log_to_file("sql_scheduler.log", "ERROR! File ^"managers.ini^" cannot be found.");

	get_datadir(g_query_file, charsmax(g_query_file));
	format(g_query_file, charsmax(g_query_file), "%s/sql_scheduler", g_query_file);

	if ( !dir_exists(g_query_file) )
		mkdir(g_query_file);

	format(g_query_file, charsmax(g_query_file), "%s/%s", g_query_file, "queries.ini");

	g_forward_query = CreateMultiForward("fw_Query_Completed", ET_IGNORE, FP_ARRAY);

	g_managers = ArrayCreate(MANAGER_DATA);
	g_types = ArrayCreate(TYPE_DATA);
	g_queries = ArrayCreate(QUERY_DATA);
	g_manager_ids = TrieCreate();
	g_type_ids = TrieCreate();

	load_managers();
}

public plugin_init() {

	register_plugin("SQL Scheduler", "1.0.0", "JohanCorn");

	g_cv_log = register_cvar("amx_sql_cheduler_log", "2");
}

public plugin_cfg() {

	load_queries();
}

public plugin_natives() {

	register_library("query_manager");

	register_native("sqls_get_manager_id", "native_get_manager_id");
	register_native("sqls_register_type", "native_register_type");
	register_native("sqls_create_query", "native_create_query");
}

public plugin_end() {

	g_plugin_end = true;
}

public native_get_manager_id() {

	new name[64];
	get_string(1, name, charsmax(name));

	return get_manager_id(name);
}

public native_register_type() {

	new name[32];
	get_string(2, name, charsmax(name));
	
	new type_id = register_type(get_param(1), name);

	TrieSetCell(g_type_ids, name, type_id);

	return type_id;
}

public native_create_query() {

	new query[QUERY_SIZE];
	get_string(2, query, charsmax(query));

	return create_query(get_param(1), query, get_param(3));
}

public get_manager_id(name[]) {

	new type_id = -1;
	TrieGetCell(g_manager_ids, name, type_id);

	return type_id;
}

public register_type(manager_id, name[]) {

	static type_data[TYPE_DATA];
	type_data[TD_MANAGER_ID] = manager_id;
	copy(type_data[TD_NAME], charsmax(type_data[TD_NAME]), name);

	return ArrayPushArray(g_types, type_data);
}

public create_query(type_id, query[], user_id) {
	
	new name[128];

	if ( !get_query_name(type_id, name, charsmax(name)) ) {

		log_to_file("sql_scheduler.log", "FATAL ERROR! Failed to Create Query: ^"%s^" | Manager or Type is cannot be found. (Query Skipped)", query);
		log_to_file("sql_scheduler.log", "Attention! Skipped Queries may cause unexpected results.");

		return 0;
	}

	static type_data[TYPE_DATA];
	ArrayGetArray(g_types, type_id, type_data);

	static query_data[QUERY_DATA];
	copy(query_data[QD_QUERY], charsmax(query_data[QD_QUERY]), query);
	query_data[QD_ID] = ++ g_query_id;
	query_data[QD_MANAGER_ID] = type_data[TD_MANAGER_ID];
	query_data[QD_TYPE_ID] = type_id;
	query_data[QD_USER_ID] = user_id;
	query_data[QD_USER_USERID] = get_user_userid(user_id);
	ArrayPushArray(g_queries, query_data);

	if ( get_pcvar_num(g_cv_log) > 1 ) {

		log_to_file("sql_scheduler.log", "%i. Thread Query: ^"%s^" | CREATE!", query_data[QD_ID], name);

		if ( get_pcvar_num(g_cv_log) > 2 )
			log_to_file("sql_scheduler.log", "%i. Thread Query: ^"%s^" | Query: %s", query_data[QD_ID], name, query);
	}

	save_queries();
	send_first_query_if_exists();

	return query_data[QD_ID];
}

public send_first_query_if_exists() {

	if ( g_plugin_end )
		return;

	if ( g_query_send )
		return;

	if ( !ArraySize(g_queries) )
		return;

	g_query_send = true;

	static query_data[QUERY_DATA];
	ArrayGetArray(g_queries, 0, query_data);

	static manager_data[MANAGER_DATA];
	ArrayGetArray(g_managers, query_data[QD_MANAGER_ID], manager_data);

	SQL_ThreadQuery(manager_data[MD_SQL], "query_callback", query_data[QD_QUERY], query_data, sizeof(query_data));

	new name[128];
	get_query_name(query_data[QD_TYPE_ID], name, charsmax(name));

	if ( get_pcvar_num(g_cv_log) < 2 )
		return;

	log_to_file("sql_scheduler.log", "%i. Thread Query: ^"%s^" | START!", query_data[QD_ID], name);
}

public query_callback(fail_state, Handle: query, error[], error_code, query_data[], size) {

	g_query_send = false;

	if ( !error_code )
	 	query_set_completed(query, query_data);
	else
		query_set_failed(query, query_data, error, error_code);
}

public query_set_failed(Handle: query, query_data[], error[], error_code) {
	
	new name[128];
	get_query_name(query_data[QD_TYPE_ID], name, charsmax(name));

	set_task(1.0, "send_first_query_if_exists");

	if ( get_pcvar_num(g_cv_log) < 1 )
		return;

	log_to_file("sql_scheduler.log", "%i. Thread Query: ^"%s^" | FAILED!", query_data[QD_ID], name);
	log_to_file("sql_scheduler.log", "%i. Thread Query: ^"%s^" | Error: %s", query_data[QD_ID], name, error);
}

public query_set_completed(Handle: query, query_data[]) {

	query_data[QD_MYSQL] = query;

	ArrayDeleteItem(g_queries, 0);

	new name[128];
	get_query_name(query_data[QD_TYPE_ID], name, charsmax(name));

	if ( get_pcvar_num(g_cv_log) > 1 )
		log_to_file("sql_scheduler.log", "%i. Thread Query: ^"%s^" | COMPLETED!", query_data[QD_ID], name);

	ExecuteForward(g_forward_query, g_forward_result, PrepareArray(query_data, QUERY_DATA, 0));

	save_queries();
	send_first_query_if_exists();
}

public load_managers() {

	static manager_data[MANAGER_DATA], data[MANAGER_DATA];
	new file = fopen(g_manager_file, "rt");

	while ( !feof(file) ) {
		
		fgets(file, data, charsmax(data));

		trim(data);

		parse(data, manager_data[MD_NAME], charsmax(manager_data[MD_NAME]), manager_data[MD_ADDRESS], charsmax(manager_data[MD_ADDRESS]), manager_data[MD_USERNAME], charsmax(manager_data[MD_USERNAME]), manager_data[MD_PASSWORD], charsmax(manager_data[MD_PASSWORD]), manager_data[MD_DATABASE], charsmax(manager_data[MD_DATABASE]))
		
		if ( data[0] == ';' || data[0] == EOS )
			continue;

		if ( TrieKeyExists(g_manager_ids, manager_data[MD_NAME]) ) {

			log_to_file("sql_scheduler.log", "FATAL ERROR! Failed to Load Manager: ^"%s^" | Manager's name is already in use.", manager_data[MD_NAME]);
			log_to_file("sql_scheduler.log", "Attention! Duplicated Managers may cause unexpected results.");

			continue;
		}

		manager_data[MD_SQL] = SQL_MakeDbTuple(manager_data[MD_ADDRESS], manager_data[MD_USERNAME], manager_data[MD_PASSWORD], manager_data[MD_DATABASE]);

		TrieSetCell(g_manager_ids, manager_data[MD_NAME], ArrayPushArray(g_managers, manager_data));
	}

	fclose(file);
}

public load_queries() {

	static data[QUERY_SIZE];
	new bool: odd, type_id = -1, file = fopen(g_query_file, "rt");

	while ( !feof(file) ) {
		
		fgets(file, data, charsmax(data));

		if ( data[0] == EOS )
			continue;

		trim(data);

		odd = !odd;

		if ( !odd ) {

			create_query(type_id, data, 0);
			type_id = -1;
		}
		else
			TrieGetCell(g_type_ids, data, type_id);
	}

	fclose(file);
}

public save_queries() {

	if ( file_exists(g_query_file) )
		delete_file(g_query_file);
	
	static query_data[QUERY_DATA], manager_data[MANAGER_DATA], type_data[TYPE_DATA];
	new file = fopen(g_query_file, "wt");

	for ( new i; i < ArraySize(g_queries); i ++ ) {

		ArrayGetArray(g_queries, i, query_data);
		ArrayGetArray(g_types, query_data[QD_TYPE_ID], type_data);
		ArrayGetArray(g_managers, type_data[TD_MANAGER_ID], manager_data);
		fprintf(file, "%s^n", type_data[TD_NAME]);
		fprintf(file, "%s^n", query_data[QD_QUERY]);
	}
 
	fclose(file);
}

public bool: get_query_name(type_id, name[], len) {

	if ( !(0 <= type_id <= TrieGetSize(g_type_ids) - 1) )
		return false;

	static type_data[TYPE_DATA];
	ArrayGetArray(g_types, type_id, type_data);

	if ( !(0 <= type_data[TD_MANAGER_ID] <= TrieGetSize(g_manager_ids) - 1) )
		return false;

	static manager_data[MANAGER_DATA];
	ArrayGetArray(g_managers, type_data[TD_MANAGER_ID], manager_data);

	format(name, len, "%s.%s", manager_data[MD_NAME], type_data[TD_NAME]);

	return true;
}