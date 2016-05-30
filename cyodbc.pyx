from cpython.mem cimport PyMem_Malloc, PyMem_Realloc, PyMem_Free

cimport sql
cimport sqlext


cdef void get_info(sql.SQLRETURN ret, sql.SQLSMALLINT handle_type,
        sql.SQLHANDLE handle):
    """Check status code and retrieve diagnostic info"""
    if ret == sql.SQL_SUCCESS:
        return
    elif ret == sql.SQL_SUCCESS_WITH_INFO:
        print("Success, but with info")
    else:
        print("No success... status code: {}".format(ret))
    cdef sql.SQLCHAR state[8]
    cdef sql.SQLINTEGER native
    cdef sql.SQLCHAR text[255]
    cdef sql.SQLSMALLINT text_length

    cdef sql.SQLRETURN diag_ret
    diag_ret = sql.SQLGetDiagRec(handle_type, handle, 1, state,
                    &native, text, 255, &text_length)
    if diag_ret == sql.SQL_SUCCESS:
        print(state, native)
        print(text.decode('utf-8'))
    elif diag_ret == sql.SQL_NO_DATA:
        print("No diag data. Hmm.")

cdef class Connection:

    cdef sql.SQLHENV h_env
    cdef sql.SQLHDBC h_dbc

    def __cinit__(self):
        self.alloc_handle()

    cdef alloc_handle(self):
        """Handle allocation time!!!"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLAllocHandle(sql.SQL_HANDLE_ENV, sql.SQL_NULL_HANDLE,
                &self.h_env)
        get_info(ret, sql.SQL_HANDLE_ENV, self.h_env)

        # Set ODBC version to 3
        cdef sql.SQLINTEGER attribute = sqlext.SQL_ATTR_ODBC_VERSION
        cdef long value = sqlext.SQL_OV_ODBC3
        ret = sql.SQLSetEnvAttr(self.h_env, attribute, <sql.SQLPOINTER>value, 0L)
        get_info(ret, sql.SQL_HANDLE_ENV, self.h_env)

    cpdef connect(self, conn_str):
        """Connect to database"""
        cdef bytes b_conn_str = conn_str.encode('utf-8')
        cdef sql.SQLCHAR* c_conn_str = b_conn_str
        cdef int slength = len(conn_str)
        self.c_connect(c_conn_str, slength)

    cdef c_connect(self, sql.SQLCHAR* conn_str, int str_len):
        """Connect to a database"""

        cdef sql.SQLRETURN ret

        ret = sql.SQLAllocHandle(sql.SQL_HANDLE_DBC, self.h_env, &self.h_dbc)
        get_info(ret, sql.SQL_HANDLE_DBC, self.h_dbc)

        ret = sqlext.SQLDriverConnect(self.h_dbc, NULL, conn_str, str_len,
                                      NULL, 0, NULL, sqlext.SQL_DRIVER_NOPROMPT)
        get_info(ret, sql.SQL_HANDLE_DBC, self.h_dbc)

    cpdef cursor(self):
        return Cursor(self)


cdef class Cursor:
    cdef Connection conn
    cdef sql.SQLHSTMT h_stmt
    cdef sql.SQLSMALLINT num_cols
    cdef sql.SQLLEN** rowstatus
    cdef sql.SQLPOINTER** columns
    cdef int* col_types
    cdef int* col_sizes
    cdef long arraysize
    cdef int array_loc

    def __cinit__(self, Connection connection):
        self.conn = connection
        self.allocate_handle()
        self.arraysize = 1
        self.array_loc = 0

    cdef allocate_handle(self):
        cdef sql.SQLRETURN ret
        ret = sql.SQLAllocHandle(sql.SQL_HANDLE_STMT, self.conn.h_dbc, &self.h_stmt)
        get_info(ret, sql.SQL_HANDLE_DBC, self.conn.h_dbc)

    cdef c_bind_cols(self):
        cdef sql.SQLCHAR column_name[255]
        cdef sql.SQLSMALLINT name_length
        cdef sql.SQLSMALLINT data_type
        cdef sql.SQLULEN column_size
        cdef sql.SQLSMALLINT decimal_digits
        cdef sql.SQLSMALLINT nullable
        cdef sql.SQLRETURN ret

        cdef int offset_size
        cdef int alloc_size
        cdef int odbc_size
        cdef int out_type

        self.rowstatus = <sql.SQLLEN**> PyMem_Malloc(self.num_cols * sizeof(sql.SQLLEN*))
        self.columns = <sql.SQLPOINTER**> PyMem_Malloc(self.num_cols * sizeof(sql.SQLPOINTER*))
        self.col_types = <int*> PyMem_Malloc(self.num_cols * sizeof(int))
        self.col_sizes = <int*> PyMem_Malloc(self.num_cols * sizeof(int))

        for i in range(self.num_cols):
            ret = sql.SQLDescribeCol(
                self.h_stmt, i+1, column_name, 255, &name_length, &data_type,
                &column_size, &decimal_digits, &nullable
            )
            get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)
            print("Col:", i, column_name[:name_length], data_type, column_size,
                  decimal_digits, nullable)

            odbc_size = 0
            offset_size = 1
            if data_type == sql.SQL_INTEGER:
                out_type = sqlext.SQL_C_LONG
                alloc_size = sizeof(long) * column_size
            elif data_type == sql.SQL_SMALLINT:
                out_type = sqlext.SQL_C_SHORT
                alloc_size = sizeof(short) * column_size
            elif data_type == sqlext.SQL_BIGINT:
                out_type = sqlext.SQL_C_SBIGINT
                alloc_size = sizeof(long) * column_size
            elif data_type == sql.SQL_REAL:
                out_type = sqlext.SQL_C_FLOAT
                alloc_size = sizeof(float) * column_size
            elif data_type in (sql.SQL_FLOAT, sql.SQL_DOUBLE):
                out_type = sqlext.SQL_C_DOUBLE
                alloc_size = sizeof(double) * column_size
            else:
                out_type = sqlext.SQL_C_CHAR
                alloc_size = sizeof(char) * column_size + 1
                odbc_size = alloc_size
                offset_size = alloc_size

            self.col_types[i] = out_type
            print("assigned col type", self.col_types[i])

            self.col_sizes[i] = offset_size
            print("allocating size", alloc_size)
            self.columns[i] = <sql.SQLPOINTER*> PyMem_Malloc(alloc_size * self.arraysize)

            self.rowstatus[i] = <sql.SQLLEN*> PyMem_Malloc(sizeof(sql.SQLLEN) * self.arraysize)

            ret = sql.SQLBindCol(
                self.h_stmt, i+1, out_type,
                self.columns[i],
                odbc_size, self.rowstatus[i]
            )
            get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

    cdef set_attributes(self):
        cdef sql.SQLRETURN ret
        ret = sql.SQLSetStmtAttr(self.h_stmt, sqlext.SQL_ATTR_ROW_ARRAY_SIZE,
                <sql.SQLPOINTER> self.arraysize, 0)

    cpdef execute(self, stmt):
        cdef bytes b_stmt = stmt.encode('utf-8')
        cdef sql.SQLCHAR* c_stmt = b_stmt
        cdef int slength = len(stmt)
        self.set_attributes()
        self.c_execute(c_stmt, slength)

    cdef c_execute(self, sql.SQLCHAR* statement, int stmt_len):
        """Do some stuff with a cursor"""
        cdef sql.SQLRETURN ret

        ret = sql.SQLPrepare(self.h_stmt, statement, stmt_len)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        ret = sql.SQLExecute(self.h_stmt)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        self.c_get_num_cols()
        self.c_bind_cols()

    cdef c_get_num_cols(self):
        """Get the number of cols in a stmt handle"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLNumResultCols(self.h_stmt, &self.num_cols)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)
        print("Num cols: {}".format(self.num_cols))

    cdef object c_fetch(self):
        """Try and fetch some rows"""
        cdef sql.SQLRETURN ret
        cdef int col_type
        cdef int rs
        cdef int size

        if self.array_loc == 0:
            ret = sql.SQLFetch(self.h_stmt)
            get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        value = None
        row = []
        for i in range(self.num_cols):
            size = self.col_sizes[i] * self.array_loc
            rs = self.rowstatus[i][self.array_loc]
            col_type = self.col_types[i]
            if rs <= 0:
                row.append(None)
                continue
            if col_type == sqlext.SQL_C_CHAR:
                row.append(<char*> self.columns[i] + size)
            elif col_type == sqlext.SQL_C_LONG:
                row.append((<int*> self.columns[i] + size)[0])
            elif col_type == sqlext.SQL_C_SHORT:
                row.append((<short*> self.columns[i] + size)[0])
            elif col_type == sqlext.SQL_C_SBIGINT:
                row.append((<long*> self.columns[i] + size)[0])
            elif col_type == sqlext.SQL_C_FLOAT:
                row.append((<float*> self.columns[i] + size)[0])
            elif col_type == sqlext.SQL_C_DOUBLE:
                row.append((<double*> self.columns[i] + size)[0])
            else:
                print("unsupported type: {}".format(col_type))
                row.append(None)

        self.array_loc += 1
        if self.array_loc == self.arraysize:
            self.array_loc = 0
        return row

    cpdef fetch(self):
        return self.c_fetch()

    def set_arraysize(self, n):
        self.arraysize = n

    def fetchmany(self, n):
        rows = []
        for i in range(n):
            rows.append(self.fetch())
        return rows
