import pandas as pd


"""
Returns a pandas dataframe from an sql query file
"""
def get_query_from_file(filename, connection):
    with open(filename, 'r') as f:
        query = f.read()
        query_output = pd.read_sql_query(query, connection)
    return query_output
