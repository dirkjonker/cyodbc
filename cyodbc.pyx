from cpython cimport bool
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


def connect(conn_str):
    conn = Connection()
    conn.connect(conn_str)
    return conn


cdef class Connection:

    cdef sql.SQLHENV h_env
    cdef sql.SQLHDBC h_dbc

    def __cinit__(self):
        self.alloc_handle()

    def __enter__(self):
        return self

    def __exit__(self, *args, **kwargs):
        self.close()

    cdef alloc_handle(self):
        """Handle allocation time!!!"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLAllocHandle(sql.SQL_HANDLE_ENV, sql.SQL_NULL_HANDLE,
                &self.h_env)
        get_info(ret, sql.SQL_HANDLE_ENV, self.h_env)

        # Set ODBC version to 3
        ret = sql.SQLSetEnvAttr(self.h_env, sqlext.SQL_ATTR_ODBC_VERSION,
                <sql.SQLPOINTER> sqlext.SQL_OV_ODBC3, 0L)
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

    cpdef close(self):
        """Disconnect from the database and free the handles"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLDisconnect(self.h_dbc)
        get_info(ret, sql.SQL_HANDLE_DBC, self.h_dbc)

        ret = sql.SQLFreeHandle(sql.SQL_HANDLE_DBC, self.h_dbc)
        get_info(ret, sql.SQL_HANDLE_DBC, self.h_dbc)

        ret = sql.SQLFreeHandle(sql.SQL_HANDLE_ENV, self.h_env)
        get_info(ret, sql.SQL_HANDLE_ENV, self.h_env)

    cpdef cursor(self):
        """Get a database cursor"""
        return Cursor(self)


cdef class Cursor:
    cdef Connection conn

    cdef bool cols_bound
    cdef bool closed

    cdef sql.SQLHSTMT h_stmt

    cdef sql.SQLULEN rows_fetched
    cdef sql.SQLUSMALLINT* row_status
    cdef sql.SQLLEN** row_indicator
    cdef sql.SQLSMALLINT num_cols
    cdef sql.SQLPOINTER** col_values
    cdef int* col_types
    cdef int* col_sizes
    cdef public long arraysize
    cdef int array_loc

    def __cinit__(self, Connection connection):
        self.conn = connection
        self.allocate_handle()
        self.arraysize = 1
        self.array_loc = 0
        self.closed = False
        self.cols_bound = False

    cdef allocate_handle(self):
        """Allocate a stmt handle"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLAllocHandle(sql.SQL_HANDLE_STMT, self.conn.h_dbc, &self.h_stmt)
        get_info(ret, sql.SQL_HANDLE_DBC, self.conn.h_dbc)

    cdef c_bind_cols(self):
        """Bind the cols using the description of the driver"""
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

        self.col_values = <sql.SQLPOINTER**> PyMem_Malloc(self.num_cols * sizeof(sql.SQLPOINTER*))
        self.col_types = <int*> PyMem_Malloc(self.num_cols * sizeof(int))
        self.col_sizes = <int*> PyMem_Malloc(self.num_cols * sizeof(int))

        self.row_indicator = <sql.SQLLEN**> PyMem_Malloc(self.num_cols * sizeof(sql.SQLLEN*))
        self.row_status = <sql.SQLUSMALLINT*> PyMem_Malloc(self.arraysize * sizeof(sql.SQLUSMALLINT))

        for i in range(self.num_cols):
            ret = sql.SQLDescribeCol(
                self.h_stmt, i+1, column_name, 255, &name_length, &data_type,
                &column_size, &decimal_digits, &nullable
            )
            get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

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
            self.col_sizes[i] = offset_size
            self.col_values[i] = <sql.SQLPOINTER*> PyMem_Malloc(self.arraysize * alloc_size)

            self.row_indicator[i] = <sql.SQLLEN*> PyMem_Malloc(self.arraysize * sizeof(sql.SQLLEN))

            ret = sql.SQLBindCol(
                self.h_stmt, i+1, out_type,
                self.col_values[i],
                odbc_size, self.row_indicator[i]
            )
            get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)
        self.cols_bound = True

    def __dealloc__(self):
        self.free_bound_cols()

    cdef free_bound_cols(self):
        """Free all the memory allocated with bindcols"""
        for i in range(self.num_cols):
            PyMem_Free(self.col_values[i])
            PyMem_Free(self.row_indicator[i])
        PyMem_Free(self.col_values)
        PyMem_Free(self.col_sizes)
        PyMem_Free(self.col_types)
        PyMem_Free(self.row_status)
        PyMem_Free(self.row_indicator)
        self.cols_bound = False

    cdef set_fetch_attributes(self):
        """Set attributes that help us fetch rows"""
        cdef sql.SQLRETURN ret

        # the number of rows to fetch each time SQLFetch is called
        ret = sql.SQLSetStmtAttr(self.h_stmt, sqlext.SQL_ATTR_ROW_ARRAY_SIZE,
                <sql.SQLPOINTER> self.arraysize, 0)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        # how many rows actually fetched after SQLFetch is called
        ret = sql.SQLSetStmtAttr(self.h_stmt, sqlext.SQL_ATTR_ROWS_FETCHED_PTR,
                <sql.SQLPOINTER> &self.rows_fetched, 0)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        # for each fetched row, the status (something might be wrong!)
        ret = sql.SQLSetStmtAttr(self.h_stmt, sqlext.SQL_ATTR_ROW_STATUS_PTR,
                <sql.SQLPOINTER> self.row_status, 0)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

    cpdef execute(self, stmt):
        """Execute a SQL statement"""
        cdef bytes b_stmt = stmt.encode('utf-8')
        cdef sql.SQLCHAR* c_stmt = b_stmt
        cdef int slength = len(stmt)
        if self.cols_bound:
            self.free_bound_cols()
        else:
            self.set_fetch_attributes()
        self.c_execute(c_stmt, slength)

    cdef c_execute(self, sql.SQLCHAR* statement, int stmt_len):
        cdef sql.SQLRETURN ret

        # ret = sql.SQLPrepare(self.h_stmt, statement, stmt_len)
        # get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        # ret = sql.SQLExecute(self.h_stmt)
        ret = sql.SQLExecDirect(self.h_stmt, statement, stmt_len)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

        self.c_get_num_cols()
        self.c_bind_cols()

    cdef c_get_num_cols(self):
        """Get the number of cols in a stmt handle"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLNumResultCols(self.h_stmt, &self.num_cols)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)

    cdef object c_fetch(self):
        """Try and fetch some rows"""
        cdef sql.SQLRETURN ret
        cdef int col_type
        cdef int rs
        cdef int size

        row = []

        if self.array_loc == 0:
            ret = sql.SQLFetch(self.h_stmt)
            if ret == sql.SQL_NO_DATA:
                return None
            get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)
            if self.rows_fetched == 0:
                return None

        for i in range(self.num_cols):
            size = self.col_sizes[i] * self.array_loc
            rs = self.row_indicator[i][self.array_loc]
            col_type = self.col_types[i]
            if rs <= 0:
                row.append(None)
                continue
            if col_type == sqlext.SQL_C_CHAR:
                row.append((<char*> self.col_values[i] + size).decode('utf-8'))
            elif col_type == sqlext.SQL_C_LONG:
                row.append((<int*> self.col_values[i] + size)[0])
            elif col_type == sqlext.SQL_C_SHORT:
                row.append((<short*> self.col_values[i] + size)[0])
            elif col_type == sqlext.SQL_C_SBIGINT:
                row.append((<long*> self.col_values[i] + size)[0])
            elif col_type == sqlext.SQL_C_FLOAT:
                row.append((<float*> self.col_values[i] + size)[0])
            elif col_type == sqlext.SQL_C_DOUBLE:
                row.append((<double*> self.col_values[i] + size)[0])
            else:
                print("unsupported type: {}".format(col_type))
                row.append(None)

        self.array_loc += 1
        if self.array_loc == self.rows_fetched:
            self.array_loc = 0
        return tuple(row)

    cpdef close(self):
        """Close the cursor, free the handle"""
        cdef sql.SQLRETURN ret
        ret = sql.SQLFreeHandle(sql.SQL_HANDLE_STMT, self.h_stmt)
        get_info(ret, sql.SQL_HANDLE_STMT, self.h_stmt)
        self.closed = True

    def fetchone(self):
        return self.c_fetch()

    def fetchmany(self, n=None):
        if n is None:
            n = self.arraysize
        rows = []
        for i in range(n):
            r = self.c_fetch()
            if r is None:
                break
            rows.append(r)
        return rows

    def fetchall(self):
        rows = []
        while True:
            r = self.c_fetch()
            if r is None:
                break
            rows.append(r)
        return rows
