# cyodbc
Cython ODBC library

Very incomplete and very incompatible with ODBC and/or Python DBAPI 2.0

Might never be compatible with anything

Use at own risk and everything

Currently it only supports executing a simple `SELECT` statement without
any parameters.
Primary goal is to be very fast with fetching lots of rows, especially if you
set `cursor.arraysize` to a reasonable amount such as 100 before you run
`cursor.execute()`

SELECT 20,000 rows with 10 columns of different column types
(varchar, int, bigint, double) from a MySQL server running on localhost,
with `cursor.arraysize` set to 100:

    pyodbc
    average time (of 10 runs): 3.2811s
    ceODBC
    average time (of 10 runs): 0.0633s
    cyodbc
    average time (of 10 runs): 0.0596s
