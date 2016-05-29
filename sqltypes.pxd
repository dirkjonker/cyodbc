cdef extern from "sqltypes.h":
    ctypedef void* SQLHANDLE
    ctypedef SQLHANDLE SQLHDBC
    ctypedef SQLHANDLE SQLHWND
    ctypedef SQLHANDLE SQLHENV
    ctypedef SQLHANDLE SQLHSTMT

    ctypedef void* SQLPOINTER
    ctypedef long SQLLEN
    ctypedef unsigned long SQLULEN

    ctypedef unsigned char SQLCHAR
    ctypedef int SQLINTEGER
    ctypedef unsigned int SQLUINTEGER
    ctypedef signed short int SQLSMALLINT
    ctypedef unsigned short int SQLUSMALLINT

    # cdef SQLLEN SQLINTEGER
    # cdef SQLULEN SQLUINTEGER
    # cdef SQLSETPOSIROW SQLUSMALLINT

    ctypedef SQLSMALLINT SQLRETURN
