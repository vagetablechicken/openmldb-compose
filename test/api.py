import requests
import argparse
import json

# curl -X POST http://openmldb-compose-api-1:9080/dbs/foo -d '{"mode":"online","sql":"'"$*"'"}'
api_url = 'http://openmldb-compose-api-1:9080/dbs/'

# -db, -m(mode), sql

parser = argparse.ArgumentParser(description='OpenMLDB API request')
parser.add_argument('-db', type=str, help='database name')
parser.add_argument('-m', type=str, help='mode')
parser.add_argument('sql', type=str, help='sql')
args = parser.parse_args()
print(args.sql, args.db, args.m)

db = args.db if args.db else None
mode = args.m if args.m else 'online'

api_url += db if db else 'foo'
# support other methods
res = requests.post(api_url, json={'mode': mode, 'sql': args.sql})
print(json.dumps(res.json(), indent=4))
