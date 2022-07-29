import _dbConfig from "./_dbConfig";

import { Pool } from "pg"


/**
 *  _dbConfig:
 *    user    : postgres database username
 *    password: the user's password
 * 
 *    host    : "localhost", "127.0.0.1" or the ip of db
 *    port    : the port of database
 * 
 *    database: "noqe" for this project
 * 
 * 
 *  Example:
 *    const _dbConfig = {
 *      user    : "myUsername",
 *      password: "verySecurePassword",
 * 
 *      host    : "localhost",
 *      port    : 12345,
 * 
 *      database: "noqe"
 *    }
 */
export default new Pool(_dbConfig);
