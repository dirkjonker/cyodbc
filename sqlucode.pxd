cimport sqltypes
from sql import *

cdef extern from "sqlucode.h":
    cdef int SQL_WCHAR
    cdef int SQL_WVARCHAR
    cdef int SQL_WLONGVARCHAR
    cdef int SQL_C_WCHAR
