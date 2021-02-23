#include <amxmodx>
#include <amxmisc>
#include <sql_scheduler>

new g_type_id;

public plugin_init() {

	g_type_id = sqls_register_type(sqls_get_manager_id("DEF_MANAGER"), "EXAMPLE");

	register_clcmd("say /time", "cmd_time");
}

public cmd_time(id) {

	client_print(id, print_chat, "Getting the Time...");

	sqls_create_query(g_type_id, "SELECT NOW();", id);

	return PLUGIN_HANDLED;
}

public fw_Query_Completed(query_data[QUERY_DATA]) {

	new id = query_data[QD_USER_ID];

	if ( !id || get_user_userid(id) != query_data[QD_USER_USERID] )
		return;

	if ( query_data[QD_TYPE_ID] == g_type_id ) {

		new now[32];
		SQL_ReadResult(query_data[QD_MYSQL], SQL_FieldNameToNum(query_data[QD_MYSQL], "NOW()"), now, charsmax(now));

		client_print(id, print_chat, "The Time is %s", now);
	}
}