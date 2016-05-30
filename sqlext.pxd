cimport sqltypes
from sql import *

cdef extern from "sqlext.h":

    # to set ODBC version
    cdef sqltypes.SQLINTEGER SQL_ATTR_ODBC_VERSION
    cdef unsigned long int SQL_OV_ODBC3

    cdef sqltypes.SQLUSMALLINT SQL_DRIVER_NOPROMPT
    cdef sqltypes.SQLUSMALLINT SQL_DRIVER_COMPLETE
    cdef sqltypes.SQLUSMALLINT SQL_DRIVER_PROMPT
    cdef sqltypes.SQLUSMALLINT SQL_DRIVER_COMPLETE_REQUIRED

    cdef int SQL_ATTR_ROW_ARRAY_SIZE
    cdef int SQL_ATTR_ROW_STATUS_PTR
    cdef int SQL_ATTR_ROWS_FETCHED_PTR

    # SQL extended datatypes
    cdef int SQL_DATE
    cdef int SQL_INTERVAL
    cdef int SQL_TIME
    cdef int SQL_TIMESTAMP
    cdef int SQL_LONGVARCHAR
    cdef int SQL_BINARY
    cdef int SQL_VARBINARY
    cdef int SQL_LONGVARBINARY
    cdef int SQL_BIGINT
    cdef int SQL_TINYINT
    cdef int SQL_BIT
    cdef int SQL_GUID

    # C datatype to SQL datatype mapping
    cdef int SQL_C_CHAR
    cdef int SQL_C_LONG
    cdef int SQL_C_SHORT
    cdef int SQL_C_FLOAT
    cdef int SQL_C_DOUBLE
    cdef int SQL_C_NUMERIC
    cdef int SQL_C_DEFAULT

    cdef int SQL_SIGNED_OFFSET
    cdef int SQL_UNSIGNED_OFFSET

    cdef int SQL_C_DATE
    cdef int SQL_C_TIME
    cdef int SQL_C_TIMESTAMP
    cdef int SQL_C_TYPE_DATE
    cdef int SQL_C_TYPE_TIME
    cdef int SQL_C_TYPE_TIMESTAMP
    cdef int SQL_C_INTERVAL_YEAR
    cdef int SQL_C_INTERVAL_MONTH
    cdef int SQL_C_INTERVAL_DAY
    cdef int SQL_C_INTERVAL_HOUR
    cdef int SQL_C_INTERVAL_MINUTE
    cdef int SQL_C_INTERVAL_SECOND
    cdef int SQL_C_INTERVAL_YEAR_TO_MONTH
    cdef int SQL_C_INTERVAL_DAY_TO_HOUR
    cdef int SQL_C_INTERVAL_DAY_TO_MINUTE
    cdef int SQL_C_INTERVAL_DAY_TO_SECOND
    cdef int SQL_C_INTERVAL_HOUR_TO_MINUTE
    cdef int SQL_C_INTERVAL_HOUR_TO_SECOND
    cdef int SQL_C_INTERVAL_MINUTE_TO_SECOND
    cdef int SQL_C_BINARY
    cdef int SQL_C_BIT
    cdef int SQL_C_SBIGINT
    cdef int SQL_C_UBIGINT
    cdef int SQL_C_TINYINT
    cdef int SQL_C_SLONG
    cdef int SQL_C_SSHORT
    cdef int SQL_C_STINYINT
    cdef int SQL_C_ULONG
    cdef int SQL_C_USHORT
    cdef int SQL_C_UTINYINT

    cdef int SQL_C_BOOKMARK

    cdef int SQL_C_GUID


    # connect using the driver connect function
    cdef sqltypes.SQLRETURN SQLDriverConnect(
        sqltypes.SQLHDBC conn_handle,
        sqltypes.SQLHWND window_handle,
        sqltypes.SQLCHAR* in_conn_str,
        sqltypes.SQLSMALLINT in_conn_str_len,
        sqltypes.SQLCHAR* out_conn_str,
        sqltypes.SQLSMALLINT buffer_length,
        sqltypes.SQLSMALLINT* out_conn_str_len,
        sqltypes.SQLUSMALLINT driver_completion
    )


cdef extern from "sqlucode.h":
    cdef int SQL_WCHAR
    cdef int SQL_WVARCHAR
    cdef int SQL_WLONGVARCHAR
    cdef int SQL_C_WCHAR
