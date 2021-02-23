#if defined _sql_scheduler_included
	#endinput
#endif

#define _sql_scheduler_included

#include <sqlx>

#define	QUERY_SIZE			1024

enum _: QUERY_DATA {
	
	QD_ID,
	QD_MANAGER_ID,
	QD_TYPE_ID,
	QD_USER_ID,
	QD_USER_USERID,
	QD_QUERY[QUERY_SIZE],
	Handle: QD_MYSQL
};

/**
 * Returns a manager's id by its name.
 *
 * @param name				Manager name.
 * @return					Manager ID, or -1 if the manager is not exists.
 */
native sqls_get_manager_id(name[]);

/**
 * Registers a type for a specific manager.
 *
 * @param manager_id		Manager ID.
 * @param name				Type's name.
 * @return					Type ID.
 */
native sqls_register_type(manager_id, name[]);

/**
 * Create an query and put it into the pool.
 *
 * Note: user_id param is not required but can be used later in validation.
 *
 * @param type_id			Type ID.
 * @param query				Sql query.
 * @param user_id			Player ID.
 * @return					Query ID.
 */
native sqls_create_query(type_id, query[], user_id = 0);

/**
 * Called when a query is complete.
 *
 * @param query_data		Query data. (Including the sql handle.)
 */
forward fw_Query_Completed(query_data[QUERY_DATA]);