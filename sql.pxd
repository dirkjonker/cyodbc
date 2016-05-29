from sqltypes cimport *

cdef extern from "sql.h":

    cdef SQLHANDLE SQL_NULL_HANDLE

    cdef SQLSMALLINT SQL_HANDLE_ENV
    cdef SQLSMALLINT SQL_HANDLE_DBC
    cdef SQLSMALLINT SQL_HANDLE_STMT
    cdef SQLSMALLINT SQL_HANDLE_DESC

    # ret values
    cdef SQLRETURN SQL_NULL_DATA
    cdef SQLRETURN SQL_DATA_AT_EXEC
    cdef SQLRETURN SQL_SUCCESS
    cdef SQLRETURN SQL_SUCCESS_WITH_INFO
    cdef SQLRETURN SQL_NO_DATA
    cdef SQLRETURN SQL_ERROR
    cdef SQLRETURN SQL_INVALID_HANDLE
    cdef SQLRETURN SQL_STILL_EXECUTING
    cdef SQLRETURN SQL_NEED_DATA

    # SQL data type codes
    cdef int SQL_UNKNOWN_TYPE
    cdef int SQL_CHAR
    cdef int SQL_NUMERIC
    cdef int SQL_DECIMAL
    cdef int SQL_INTEGER
    cdef int SQL_SMALLINT
    cdef int SQL_FLOAT
    cdef int SQL_REAL
    cdef int SQL_DOUBLE
    cdef int SQL_DATETIME
    cdef int SQL_VARCHAR
    cdef int SQL_TYPE_DATE
    cdef int SQL_TYPE_TIME
    cdef int SQL_TYPE_TIMESTAMP


    # ODBC functions

    cdef SQLRETURN SQLAllocHandle(SQLSMALLINT HandleType,
            SQLHANDLE InputHandle, SQLHANDLE* OutputHandlePtr)

    cdef SQLRETURN SQLBindCol(SQLHSTMT StatementHandle,
            SQLUSMALLINT ColumnNumber, SQLSMALLINT TargetType,
            SQLPOINTER TargetValue, SQLLEN BufferLength, SQLLEN *StrLen_or_Ind)

    cdef SQLRETURN SQLDescribeCol(SQLHSTMT StatementHandle,
            SQLUSMALLINT ColumnNumber, SQLCHAR *ColumnName,
            SQLSMALLINT BufferLength, SQLSMALLINT *NameLength,
            SQLSMALLINT *DataType, SQLULEN *ColumnSize,
            SQLSMALLINT *DecimalDigits, SQLSMALLINT *Nullable)

    cdef SQLRETURN SQLExecute(SQLHSTMT StatementHandle)

    cdef SQLRETURN SQLFetch(SQLHSTMT StatementHandle)

    cdef SQLRETURN SQLGetDiagRec(SQLSMALLINT HandleType, SQLHANDLE Handle,
            SQLSMALLINT RecNumber, SQLCHAR *Sqlstate, SQLINTEGER *NativeError,
            SQLCHAR *MessageText, SQLSMALLINT BufferLength,
            SQLSMALLINT *TextLength)

    cdef SQLRETURN SQLNumResultCols(SQLHSTMT StatementHandle,
            SQLSMALLINT *ColumnCount)

    cdef SQLRETURN SQLPrepare(SQLHSTMT StatementHandle, SQLCHAR *StatementText,
            SQLINTEGER TextLength)

    cdef SQLRETURN SQLSetEnvAttr(SQLHENV EnvironmentHandle,
            SQLINTEGER Attribute, SQLPOINTER Value, SQLINTEGER StringLength)

    cdef SQLRETURN SQLSetStmtAttr(SQLHSTMT StatementHandle,
            SQLINTEGER Attribute, SQLPOINTER Value, SQLINTEGER StringLength)
