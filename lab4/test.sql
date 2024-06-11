--drop table table2;
--DROP TABLE table1;
--DROP SEQUENCE table1_seq;
--DROP SEQUENCE table2_seq;


DECLARE v_col VARCHAR2(8000);
output_cursor SYS_REFCURSOR;
json_create_table1 CLOB := '{
      "query_type": "CREATE TABLE",
      "table": "table1",
      "columns": [
         {
            "name": "id", "type": "NUMBER"
         },
         {
            "name": "num", "type": "NUMBER"
         },
         {
            "name": "val", "type": "VARCHAR2(200)"
         }
      ],
      "primary_keys": ["id"]
   }';
json_create_table2 CLOB := '{
      "query_type": "CREATE TABLE",
      "table": "table2",
      "columns": [
         {
            "name": "id", "type": "NUMBER"
         },
         {
            "name": "num", "type": "NUMBER"
         },
         {
            "name": "val", "type": "VARCHAR2(200)"
         },
         {
            "name": "table1_k", "type": "NUMBER"
         }
         
      ],
      "primary_keys": ["id"],
      "foreign_keys": [{"field": "id", "table": "table1", "ref_field": "id"}]
   }';
json_select_table1_table2 CLOB := '
   {
  "query_type": "SELECT",
  "columns": ["*"],
  "tables": ["table1"],
  "join_block":
  [
    "RIGHT",
    "table2",
    "table2.table1_k = table1.id"
  ],
  "filter_conditions": [
    {
      "condition_type": "included",
      "condition": {
        "query_type": "SELECT",
        "columns": ["id"],
        "tables": ["table2"],
        "filter_conditions": [
          {"condition": "val like ''%a%''", "operator": "AND"},
          {
            "condition": "num between 2 and 4",
            "operator": "AND"
          }
        ],
        "operator": "IN",
        "search_col": "table1.id"
      },
      "operator": "AND"
    }
  ]
}

   ';
json_test_join_select CLOB := '{
  "query_type": "SELECT",
  "columns": [
    "*"
  ],
  "tables": [
    "table1"
  ],
  "join_block": [],
  "filter_conditions": [
    {
      "condition_type": "included",
      "condition": {
        "query_type": "SELECT",
        "column": "id",
        "tables": [
          "table2"
        ],
        "filter_conditions": [
                  {
            "condition": "id between 3 and 5",
            "operator": "AND"
          },
          {
            "condition": "name like ''%''",
            "operator": "AND"
          }

        ],
        "operator": "NOT IN",
        "search_col": "id"
      },
      "operator": "AND"
    }
  ]
}';
json_test_insert CLOB := '{
    "query_type": "INSERT",
     "table": "table1",
      "columns": ["num", "val"],
  "values": ["1", "''val''"]}';
-- 
BEGIN 
--     parse_json_proc(json_test_join_select, output_cursor);
--     parse_json_proc(json_create_table1, output_cursor);
--     parse_json_proc(json_create_table2, output_cursor);
--    parse_json_proc(json_select_table1_table2, output_cursor);
    parse_json_proc(json_test_insert, output_cursor);
END;

----------------------------------------------------------